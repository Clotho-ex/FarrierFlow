import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct PhotographCollectionView: View {
    @State private var model: PhotographCollectionModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var showsPhotoPicker = false
    @State private var showsCamera = false
    @State private var selectedPhotograph: PhotographItem?
    @State private var pendingDeletion: PhotographItem?
    private let library: PhotographLibrary

    init(
        visitHorseID: PersistentIdentifier,
        horseName: String,
        library: PhotographLibrary
    ) {
        self.library = library
        _model = State(
            initialValue: PhotographCollectionModel(
                visitHorseID: visitHorseID,
                horseName: horseName,
                library: library
            )
        )
    }

    var body: some View {
        content
            .overlay {
                if model.isProcessing {
                    ProgressView("Processing Photograph…")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 12))
                }
            }
            .navigationTitle("Hoof Photographs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    addMenu
                }
            }
            .task {
                model.load()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.protectedDataDidBecomeAvailableNotification
                )
            ) { _ in
                model.load()
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    defer { pickerItem = nil }
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await model.add(sourceData: data)
                    } else {
                        model.alert = FeatureAlert(
                            title: "Couldn’t Import Photograph",
                            message: "The selected image couldn’t be read. Choose another image."
                        )
                    }
                }
            }
            .sheet(isPresented: $showsCamera) {
                CameraCaptureView { data in
                    Task {
                        await model.add(sourceData: data)
                    }
                } onFailure: {
                    model.alert = FeatureAlert(
                        title: "Couldn’t Capture Photograph",
                        message: "The captured image couldn’t be read. Try taking another photograph."
                    )
                }
                .ignoresSafeArea()
            }
            .photosPicker(
                isPresented: $showsPhotoPicker,
                selection: $pickerItem,
                matching: .images
            )
            .sheet(item: $selectedPhotograph) { item in
                PhotographFullImageView(
                    item: item,
                    url: library.canonicalURL(for: item.id),
                    horseName: model.horseName,
                    position: model.items.firstIndex(where: { $0.id == item.id })
                        .map { $0 + 1 } ?? 1,
                    total: model.items.count
                )
            }
            .confirmationDialog(
                "Delete Photograph?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { item in
                Button("Delete Photograph", role: .destructive) {
                    Task {
                        await model.delete(id: item.id)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { item in
                Text(
                    item.availability == .available
                        ? "This removes the photograph from this horse’s visit."
                        : "This removes the unavailable photograph record."
                )
            }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading, model.items.isEmpty {
            ProgressView("Loading Photographs…")
        } else if model.hasInitialLoadFailure {
            unavailableContent
        } else if model.items.isEmpty {
            ContentUnavailableView(
                "No Photographs",
                systemImage: "photo.on.rectangle",
                description: Text("Add a hoof photograph with the camera or photo library.")
            )
        } else {
            VStack(spacing: 0) {
                if model.loadState == .failed {
                    refreshFailure
                }

                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 140), spacing: 12),
                        ],
                        spacing: 12
                    ) {
                        ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                            PhotographGridItemView(
                                item: item,
                                url: library.canonicalURL(for: item.id),
                                position: index + 1,
                                total: model.items.count,
                                onOpen: { selectedPhotograph = item },
                                onDelete: { pendingDeletion = item }
                            )
                        }
                    }
                    .padding()

                    if !model.canAdd,
                       model.availableCount >= PhotographConstants.maximumPhotographsPerVisitHorse {
                        Text("This horse has 16 photographs. Delete one before adding another.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .accessibilityIdentifier("photograph-limit-message")
                    }
                }
            }
        }
    }

    private var unavailableContent: some View {
        ContentUnavailableView {
            Label("Photographs Unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            loadFailureMessage
        } actions: {
            Button("Retry") {
                model.load()
            }
        }
    }

    private var refreshFailure: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Photographs Unavailable")
                    .font(.subheadline.weight(.semibold))
                loadFailureMessage
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Retry") {
                model.load()
            }
        }
        .padding()
        .background(.bar)
    }

    @ViewBuilder
    private var loadFailureMessage: some View {
        if let loadFailure = model.loadFailure {
            Text(loadFailure.message)
        } else {
            Text("The photographs couldn’t be loaded. Try again.")
        }
    }

    private var addMenu: some View {
        Menu {
            Button {
                requestCamera()
            } label: {
                Label("Camera", systemImage: "camera")
            }

            Button {
                showsPhotoPicker = true
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }
        } label: {
            Label("Add Photograph", systemImage: "plus")
        }
        .disabled(!model.canAdd)
        .accessibilityIdentifier("photograph-add-menu")
        .accessibilityValue(addMenuAccessibilityValue)
    }

    private var addMenuAccessibilityValue: String {
        switch model.loadState {
        case .loading:
            "Loading photographs"
        case .loaded:
            "\(model.availableCount) of \(PhotographConstants.maximumPhotographsPerVisitHorse)"
        case .failed:
            "Photographs unavailable"
        }
    }

    private func requestCamera() {
        guard cameraIsAvailable else {
            model.alert = FeatureAlert(
                title: "Camera Unavailable",
                message: "Use the photo library to add a photograph on this device."
            )
            return
        }

        Task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                showsCamera = true
            case .notDetermined:
                if await AVCaptureDevice.requestAccess(for: .video) {
                    showsCamera = true
                } else {
                    showCameraPermissionError()
                }
            case .denied, .restricted:
                showCameraPermissionError()
            @unknown default:
                showCameraPermissionError()
            }
        }
    }

    private var cameraIsAvailable: Bool {
        #if DEBUG
        if UITestLaunchConfiguration().forcesCameraUnavailable {
            return false
        }
        #endif
        return UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private func showCameraPermissionError() {
        model.alert = FeatureAlert(
            title: "Camera Access Needed",
            message: "Allow camera access in Settings, or use the photo library."
        )
    }
}

private struct PhotographGridItemView: View {
    let item: PhotographItem
    let url: URL
    let position: Int
    let total: Int
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.rowContent) {
            Button(action: onOpen) {
                PhotographThumbnailView(
                    item: item,
                    url: url,
                    position: position,
                    total: total
                )
            }
            .buttonStyle(.plain)

            HStack {
                Text(item.createdAt, format: .dateTime.month().day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
    }
}

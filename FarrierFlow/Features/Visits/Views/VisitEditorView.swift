import SwiftData
import SwiftUI

struct VisitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PhotographLibrary.self) private var photographLibrary
    @State private var model: VisitEditorModel
    @State private var showsDismissConfirmation = false
    @State private var showsDiscardVisitConfirmation = false
    @FocusState private var focusedWorkNotesID: PersistentIdentifier?

    init(
        visitID: PersistentIdentifier,
        container: ModelContainer,
        mode: VisitEditorMode = .inProgress
    ) {
        _model = State(
            initialValue: VisitEditorModel(visitID: visitID, in: container, mode: mode)
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.loadState {
                case .loading:
                    ProgressView("Loading Visit…")
                case .failed:
                    ContentUnavailableView {
                        Label("Visit Unavailable", systemImage: "exclamationmark.circle")
                    } description: {
                        Text("The visit couldn’t be loaded.")
                    } actions: {
                        Button("Retry") {
                            model.retry()
                        }
                    }
                case .loaded:
                    editorForm
                }
            }
            .navigationTitle("Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        requestDismissal()
                    }
                }
                if model.mode == .inProgress, model.loadState == .loaded {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Discard Visit", role: .destructive) {
                                showsDiscardVisitConfirmation = true
                            }
                        } label: {
                            Label("Actions", systemImage: "ellipsis.circle")
                        }
                        .accessibilityIdentifier("visit-actions-menu")
                    }
                }
                if model.mode == .inProgress {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Save Progress") {
                            focusedWorkNotesID = nil
                            model.saveProgress()
                        }
                        .accessibilityIdentifier("visit-save-progress")
                        .disabled(!model.canSaveProgress)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Complete Visit") {
                            focusedWorkNotesID = nil
                            if model.completeVisit() {
                                dismiss()
                            }
                        }
                        .accessibilityIdentifier("visit-complete")
                        .disabled(!model.canComplete)
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save Changes") {
                            focusedWorkNotesID = nil
                            if model.saveCorrection() {
                                dismiss()
                            }
                        }
                        .accessibilityIdentifier("visit-save-correction")
                        .disabled(!model.canSaveCorrection)
                    }
                }
            }
        }
        .interactiveDismissDisabled(model.isDirty)
        .onAppear {
            model.load()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                if model.mode == .inProgress, model.isDirty {
                    _ = model.saveProgressForBackground()
                }
            case .active:
                model.surfacePendingBackgroundSaveErrorIfNeeded()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .confirmationDialog(
            "Discard Unsaved Changes?",
            isPresented: $showsDismissConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Unsaved Changes", role: .destructive) {
                model.discardUnsavedChanges()
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your unsaved visit changes will be lost.")
        }
        .confirmationDialog(
            "Clear Work Notes?",
            isPresented: Binding(
                get: { model.pendingOutcomeChange != nil },
                set: { isPresented in
                    if !isPresented {
                        model.cancelPendingOutcomeChange()
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Clear Work Notes", role: .destructive) {
                model.confirmPendingOutcomeChange()
            }
            Button("Keep Editing", role: .cancel) {
                model.cancelPendingOutcomeChange()
            }
        } message: {
            Text("Changing this outcome will clear its Work Notes.")
        }
        .confirmationDialog(
            "Discard Visit?",
            isPresented: $showsDiscardVisitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Visit", role: .destructive) {
                Task {
                    do {
                        try await photographLibrary.discardInProgressVisit(id: model.visitID)
                        dismiss()
                    } catch {
                        model.alert = FeatureAlert(
                            title: "Couldn’t Discard Visit",
                            message: "The visit and its photographs were kept. Try again."
                        )
                    }
                }
            }
            Button("Keep Visit", role: .cancel) {}
        } message: {
            Text("This will delete the in-progress visit and its recorded outcomes.")
        }
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
    }

    @ViewBuilder
    private var editorForm: some View {
        if let draft = model.draft {
            Form {
                if model.isDirty {
                    Section {
                        Text("Unsaved Changes")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("visit-unsaved-state")
                    }
                }
                ForEach(draft.horses) { horse in
                    Section(horse.horseName) {
                        VisitHorseOutcomeRow(
                            horse: horse,
                            selectableOutcomes: VisitRules.selectableOutcomes(
                                for: model.mode
                            ),
                            workNotes: Binding(
                                get: {
                                    model.draft?.horses.first(where: { $0.id == horse.id })?.workNotes
                                        ?? ""
                                },
                                set: { model.setWorkNotes($0, for: horse.id) }
                            ),
                            focusedWorkNotesID: $focusedWorkNotesID,
                            onOutcomeSelected: { outcome in
                                if outcome != .serviced {
                                    focusedWorkNotesID = nil
                                }
                                _ = model.requestOutcomeChange(
                                    for: horse.id,
                                    to: outcome
                                )
                            }
                        )
                        NavigationLink {
                            PhotographCollectionView(
                                visitHorseID: horse.id,
                                horseName: horse.horseName,
                                library: photographLibrary
                            )
                        } label: {
                            PhotographCountLabel(
                                visitHorseID: horse.id,
                                library: photographLibrary
                            )
                        }
                        .accessibilityIdentifier("visit-photographs-\(horse.horseName)")
                    }
                }
            }
        } else {
            ContentUnavailableView("Visit Unavailable", systemImage: "exclamationmark.circle")
        }
    }

    private func requestDismissal() {
        if model.isDirty {
            showsDismissConfirmation = true
        } else {
            dismiss()
        }
    }
}

private struct VisitEditorPreview: View {
    private let fixture: PreviewFixtures.VisitPreviewFixture?

    init(state: PreviewFixtures.VisitPreviewState) {
        fixture = try? PreviewFixtures.visitPreview(state: state)
    }

    var body: some View {
        if let fixture {
            VisitEditorView(visitID: fixture.visitID, container: fixture.container)
                .modelContainer(fixture.container)
        } else {
            ModelContainerFailureView()
        }
    }
}

#Preview("Visit — Pending") {
    VisitEditorPreview(state: .pending)
}

#Preview("Visit — Partially Saved, Accessibility") {
    VisitEditorPreview(state: .partiallySaved)
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}

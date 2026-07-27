import SwiftData
import SwiftUI

struct VisitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var model: VisitDetailModel
    @State private var showsEditor = false
    private let showsDismissAction: Bool

    init(
        visitID: PersistentIdentifier,
        container: ModelContainer,
        showsDismissAction: Bool = false
    ) {
        self.showsDismissAction = showsDismissAction
        _model = State(
            initialValue: VisitDetailModel(visitID: visitID, in: container)
        )
    }

    var body: some View {
        if showsDismissAction {
            NavigationStack {
                detailContent
            }
        } else {
            detailContent
        }
    }

    @ViewBuilder
    private var detailContent: some View {
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
                detailList
            }
        }
        .navigationTitle("Visit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDismissAction {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("visit-detail-done")
                }
            }
            if model.loadState == .loaded {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(model.editorMode == .inProgress ? "Resume Visit" : "Edit") {
                        showsEditor = true
                    }
                    .accessibilityIdentifier(
                        model.editorMode == .inProgress
                            ? "visit-resume-action"
                            : "visit-edit-action"
                    )
                }
            }
        }
        .onAppear {
            model.load()
        }
        .sheet(isPresented: $showsEditor, onDismiss: model.load) {
            VisitEditorView(
                visitID: model.visitID,
                container: modelContainer,
                mode: model.editorMode
            )
        }
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
    }

    @Environment(\.modelContext) private var context

    private var modelContainer: ModelContainer {
        context.container
    }

    @ViewBuilder
    private var detailList: some View {
        if let detail = model.detail {
            List {
                Section("Visit") {
                    LabeledContent {
                        Text(detail.startedAt, format: .dateTime.month().day().year().hour().minute())
                    } label: {
                        Text("Work Date")
                    }
                    LabeledContent("Status") {
                        Text(detail.completedAt == nil ? "In Progress" : "Completed")
                            .accessibilityIdentifier("visit-detail-status")
                    }
                }
                Section("Service Location") {
                    if let barnID = detail.barnID {
                        NavigationLink {
                            BarnDetailView(barnID: barnID)
                        } label: {
                            locationSnapshot(detail)
                        }
                    } else {
                        locationSnapshot(detail)
                    }
                }
                Section("Horses") {
                    ForEach(detail.horses) { horse in
                        VisitHorseResultRow(horse: horse)
                    }
                }
            }
        } else {
            ContentUnavailableView("Visit Unavailable", systemImage: "exclamationmark.circle")
        }
    }

    @ViewBuilder
    private func locationSnapshot(_ detail: VisitDetail) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(detail.serviceLocationNameSnapshot)
                .font(Typography.recordTitle)
            if let address = detail.serviceLocationAddressSnapshot {
                Text(address)
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("visit-detail-service-location-snapshot")
        .accessibilityLabel("Service Location")
        .accessibilityValue(
            Text(
                locationAccessibilityValue(
                    name: detail.serviceLocationNameSnapshot,
                    address: detail.serviceLocationAddressSnapshot
                )
            )
        )
    }

    private func locationAccessibilityValue(name: String, address: String?) -> String {
        [name, address]
            .compactMap { $0 }
            .formatted(.list(type: .and).locale(locale))
    }
}

private struct VisitDetailPreview: View {
    private let fixture: PreviewFixtures.VisitPreviewFixture?

    init(state: PreviewFixtures.VisitPreviewState) {
        fixture = try? PreviewFixtures.visitPreview(state: state)
    }

    var body: some View {
        if let fixture {
            VisitDetailView(visitID: fixture.visitID, container: fixture.container)
                .modelContainer(fixture.container)
        } else {
            ModelContainerFailureView()
        }
    }
}

#Preview("Visit — Completed") {
    VisitDetailPreview(state: .completed)
}

#Preview("Visit — Missing Service Location") {
    VisitDetailPreview(state: .missingBarn)
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}

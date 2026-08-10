import SwiftData
import SwiftUI

struct VisitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(PhotographLibrary.self) private var photographLibrary
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model: VisitEditorModel
    @State private var showsDismissConfirmation = false
    @State private var showsDiscardVisitConfirmation = false
    @State private var addServiceHorse: VisitHorseDraft?
    @State private var workItemEditorTarget: WorkItemEditorTarget?
    @FocusState private var focusedWorkNotesID: PersistentIdentifier?
    private let onCompleted: ((PersistentIdentifier) -> Void)?

    init(
        visitID: PersistentIdentifier,
        container: ModelContainer,
        mode: VisitEditorMode = .inProgress,
        onCompleted: ((PersistentIdentifier) -> Void)? = nil
    ) {
        _model = State(
            initialValue: VisitEditorModel(visitID: visitID, in: container, mode: mode)
        )
        self.onCompleted = onCompleted
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
                if subscription.allowsMutations, model.mode == .inProgress, model.loadState == .loaded {
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
                if subscription.allowsMutations, model.mode == .inProgress {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Save Progress") {
                            guard subscription.allowsMutations else { return }
                            focusedWorkNotesID = nil
                            model.saveProgress()
                        }
                        .accessibilityIdentifier("visit-save-progress")
                        .disabled(!model.canSaveProgress)
                        Spacer()
                        Button("Complete Visit") {
                            guard subscription.allowsMutations else { return }
                            focusedWorkNotesID = nil
                            if model.completeVisit() {
                                onCompleted?(model.visitID)
                                dismiss()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("visit-complete")
                        .disabled(!model.canComplete)
                    }
                } else if subscription.allowsMutations {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save Changes") {
                            guard subscription.allowsMutations else { return }
                            focusedWorkNotesID = nil
                            if model.saveCorrection() {
                                dismiss()
                            }
                        }
                        .accessibilityIdentifier("visit-save-correction")
                        .disabled(!model.canSaveCorrection)
                    }
                }
                if model.loadState == .loaded {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            focusedWorkNotesID = nil
                        }
                        .accessibilityIdentifier("visit-dismiss-keyboard")
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
                if subscription.allowsMutations, model.mode == .inProgress, model.isDirty {
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
            "Clear Recorded Work?",
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
            Button("Clear Recorded Work", role: .destructive) {
                guard subscription.allowsMutations else { return }
                model.confirmPendingOutcomeChange()
            }
            Button("Keep Editing", role: .cancel) {
                model.cancelPendingOutcomeChange()
            }
        } message: {
            Text("Changing this outcome will clear its recorded services and Work Notes.")
        }
        .confirmationDialog(
            "Discard Visit?",
            isPresented: $showsDiscardVisitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Visit", role: .destructive) {
                guard subscription.allowsMutations else { return }
                Task {
                    do {
                        try await photographLibrary.discardInProgressVisit(id: model.visitID)
                        dismiss()
                    } catch {
                        model.alert = FeatureAlert(
                            title: "Couldn’t Discard Visit",
                            message: "The visit and its photos were kept. Try again."
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
                if model.mode == .inProgress,
                   let completionBlocker = model.completionBlocker {
                    Section("Complete Visit") {
                        Text(completionGuidance(for: completionBlocker))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("visit-completion-requirement")
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
                        .disabled(!subscription.allowsMutations)
                        if horse.outcome != .notServiced {
                            visitWorkItems(for: horse)
                        }
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
            .scrollDismissesKeyboard(.interactively)
            .sheet(item: $addServiceHorse) { horse in
                NavigationStack {
                    AddServicePickerView(
                        model: model,
                        visitHorseID: horse.id
                    )
                }
            }
            .sheet(item: $workItemEditorTarget) { target in
                WorkItemEditorView(
                    model: model,
                    visitHorseID: target.visitHorseID,
                    workItem: target.workItem
                )
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

    @ViewBuilder
    private func visitWorkItems(for horse: VisitHorseDraft) -> some View {
        Text("Services")
            .font(Typography.recordMetadata)
            .foregroundStyle(.secondary)

        if horse.workItems.isEmpty {
            Text("No Recorded Services")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("visit-work-items-empty-\(horse.horseName)")
        } else {
            ForEach(horse.workItems) { workItem in
                if subscription.allowsMutations {
                    Button {
                        workItemEditorTarget = WorkItemEditorTarget(
                            visitHorseID: horse.id,
                            workItem: workItem
                        )
                    } label: {
                    HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.rowContent) {
                        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                            Text(workItem.serviceNameSnapshot)
                                .font(Typography.recordTitle)
                            if workItem.serviceIsArchived {
                                Text("Archived")
                                    .font(Typography.recordMetadata)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: SpacingTokens.rowContent)
                        Text(formattedAmount(for: workItem))
                            .font(Typography.recordMetadata)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .accessibilityIdentifier(
                                "visit-work-item-amount-\(horse.horseName)-\(workItem.serviceNameSnapshot)"
                            )
                    }
                    }
                    .accessibilityLabel(
                    "\(workItem.serviceNameSnapshot), \(formattedAmount(for: workItem))"
                )
                    .accessibilityHint("Edit Service")
                    .accessibilityIdentifier(
                    "visit-work-item-\(horse.horseName)-\(workItem.serviceNameSnapshot)"
                    )
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.rowContent) {
                        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                            Text(workItem.serviceNameSnapshot)
                                .font(Typography.recordTitle)
                            if workItem.serviceIsArchived {
                                Text("Archived")
                                    .font(Typography.recordMetadata)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: SpacingTokens.rowContent)
                        Text(formattedAmount(for: workItem))
                            .font(Typography.recordMetadata)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(workItem.serviceNameSnapshot), \(formattedAmount(for: workItem))"
                    )
                }
            }
        }

        if subscription.allowsMutations {
        Button("Add Service", systemImage: "plus") {
            guard subscription.allowsMutations else { return }
            switch model.requestAddService(to: horse.id) {
            case .createService, .chooseService:
                addServiceHorse = horse
            case .serviceAdded:
                break
            }
        }
        .accessibilityIdentifier("visit-add-service-\(horse.horseName)")
        }

        if let subtotal = try? WorkItemRules.subtotal(for: horse.workItems),
           let formattedSubtotal = MoneyFormatter.usd(minorUnits: subtotal, locale: locale) {
            LabeledContent("Subtotal", value: formattedSubtotal)
                .font(Typography.recordMetadata)
                .monospacedDigit()
                .accessibilityLabel("Subtotal, \(formattedSubtotal)")
                .accessibilityIdentifier("visit-work-item-subtotal-\(horse.horseName)")
        } else {
            Text("Subtotal Unavailable")
                .font(Typography.recordMetadata)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("visit-work-item-subtotal-\(horse.horseName)")
        }
    }

    private func formattedAmount(for workItem: WorkItemDraft) -> String {
        MoneyFormatter.usd(minorUnits: workItem.amountMinorUnits, locale: locale)
            ?? String(localized: "Unavailable", locale: locale)
    }

    private func completionGuidance(
        for blocker: VisitDraftViolation
    ) -> LocalizedStringKey {
        switch blocker {
        case .pendingOutcomePreventsCompletion:
            "Choose an outcome for every horse."
        case .completionRequiresServicedHorse:
            "Mark at least one horse as Serviced."
        case .servicedHorseRequiresWorkItem:
            "Add a recorded Service for every serviced horse."
        case .unknownOutcome,
             .duplicateHorse,
             .workNotesRequireServicedOutcome,
             .notServicedHorseHasWorkItems,
             .invalidWorkItem:
            "Review the Visit details before completing it."
        }
    }
}

private struct WorkItemEditorTarget: Identifiable {
    let visitHorseID: PersistentIdentifier
    let workItem: WorkItemDraft

    var id: UUID {
        workItem.id
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

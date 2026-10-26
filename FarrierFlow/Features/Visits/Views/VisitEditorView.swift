import SwiftData
import SwiftUI

struct VisitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.analyticsClient) private var analyticsClient
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var context
    @Environment(PhotographLibrary.self) private var photographLibrary
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model: VisitEditorModel
    @State private var showsDismissConfirmation = false
    @State private var showsDiscardVisitConfirmation = false
    @State private var showsApplyWork = false
    @State private var expandedHorseID: PersistentIdentifier?
    @State private var deletion = RecordDeletionController()
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if subscription.allowsMutations, model.mode == .inProgress,
                   model.loadState == .loaded, focusedWorkNotesID == nil {
                    visitFooter
                }
            }
            .disabled(deletion.isDeleting)
            .navigationTitle("Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.mode == .inProgress ? "Close" : "Cancel") {
                        requestDismissal()
                    }
                    .tint(ColorTokens.textSecondary)
                    .accessibilityIdentifier("visit-close")
                }
                if subscription.allowsMutations, model.mode == .inProgress, model.loadState == .loaded {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if let address = model.serviceLocationAddress,
                               let url = ServiceLocationDirections.url(for: address) {
                                Link("Directions", destination: url)
                            }
                            if model.canComplete {
                                Button("Save Progress", action: saveProgress)
                                    .disabled(!model.canSaveProgress)
                                    .accessibilityIdentifier("visit-save-progress")
                            }
                            if model.canApplyWorkToHorses {
                                Button("Apply Work to Horses", systemImage: "rectangle.on.rectangle") {
                                    focusedWorkNotesID = nil
                                    showsApplyWork = true
                                }
                                .accessibilityIdentifier("visit-apply-work-action")
                            }
                            if model.hasScheduledAppointment {
                                Divider()
                                Button("Delete Visit", systemImage: "trash", role: .destructive) {
                                    requestDeletion()
                                }
                            }
                        } label: {
                            Label("Actions", systemImage: "ellipsis")
                        }
                        .tint(ColorTokens.textSecondary)
                        .accessibilityIdentifier("visit-actions-menu")
                    }
                } else if subscription.allowsMutations, model.mode == .correction {
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
            if expandedHorseID == nil {
                expandedHorseID = model.draft?.horses.first(where: { !$0.hasRecordedOutcome })?.id
                    ?? model.draft?.horses.first?.id
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
        .alert("Delete Visit?", isPresented: $showsDiscardVisitConfirmation,
               presenting: deletion.impact) { impact in
            Button("Delete Visit", role: .destructive) {
                guard subscription.allowsMutations else { return }
                Task {
                    if await deletion.delete(impact, using: photographLibrary) {
                        dismiss()
                    } else {
                        model.alert = deletion.alert
                    }
                }
            }
            .accessibilityIdentifier("visit-delete-confirmation")
            Button("Cancel", role: .cancel) {}
        } message: { impact in
            Text(impact.warning)
        }
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
    }

    @ViewBuilder
    private var editorForm: some View {
        if let draft = model.draft {
            let sharedClient = model.sharedClientName
            Form {
                if model.mode == .inProgress {
                    visitSummary(draft, sharedClientName: sharedClient)
                } else {
                    Section {
                        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                            Text("Corrections do not change saved invoices.")
                                .font(.footnote)
                                .accessibilityIdentifier("visit-correction-invoice-warning")
                            if model.isDirty {
                                Text("Unsaved Changes")
                                    .accessibilityIdentifier("visit-unsaved-state")
                            }
                        }
                        .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .listRowBackground(Color.clear)
                }
                if model.mode == .correction, let blocker = model.correctionBlocker {
                    RecordSection(Text("Save Changes")) {
                        Text(completionGuidance(for: blocker))
                            .foregroundStyle(ColorTokens.textSecondary)
                            .accessibilityIdentifier("visit-correction-requirement")
                    }
                    .listRowBackground(ColorTokens.surface)
                }
                ForEach(draft.horses) { horse in
                    horseSection(horse, showsClient: sharedClient == nil)
                }
            }
            .farrierFlowScrollBackground()
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
            .sheet(isPresented: $showsApplyWork) {
                NavigationStack {
                    ApplyVisitWorkView(model: model)
                }
            }
        } else {
            ContentUnavailableView("Visit Unavailable", systemImage: "exclamationmark.circle")
        }
    }

    private func visitSummary(_ draft: VisitDraft, sharedClientName: String?) -> some View {
        Section {
            VStack(alignment: .leading, spacing: SpacingTokens.related) {
                if let location = model.serviceLocationName {
                    Text(verbatim: location)
                        .font(.title2.weight(.semibold))
                        .accessibilityIdentifier("visit-service-location")
                }
                if let client = sharedClientName {
                    Text("Client · \(client)")
                        .font(.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .accessibilityIdentifier("visit-shared-client")
                }
                Text("\(model.recordedHorseCount) of \(draft.horses.count) horses recorded")
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .accessibilityIdentifier("visit-progress-summary")
                ProgressView(value: Double(model.recordedHorseCount), total: Double(max(draft.horses.count, 1)))
                    .tint(ColorTokens.brandPrimary)
                    .accessibilityHidden(true)
                if let blocker = model.completionBlocker, blocker != .pendingOutcomePreventsCompletion {
                    Text(completionGuidance(for: blocker))
                        .font(.footnote)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("visit-completion-requirement")
                }
                if model.isDirty {
                    Text("Unsaved Changes")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ColorTokens.warning)
                        .padding(.horizontal, SpacingTokens.related)
                        .padding(.vertical, SpacingTokens.rowContent)
                        .background(ColorTokens.warningTint, in: .capsule)
                        .accessibilityIdentifier("visit-unsaved-state")
                }
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func horseSection(_ horse: VisitHorseDraft, showsClient: Bool) -> some View {
        if model.mode == .inProgress {
            Section {
                VisitHorseExecutionHeader(
                    horse: horse, information: model.horseContext[horse.id],
                    showsClient: showsClient,
                    isExpanded: Binding(
                        get: { expandedHorseID == horse.id },
                        set: { expanded in
                            focusedWorkNotesID = nil
                            expandedHorseID = expanded ? horse.id : nil
                        }
                    )
                )
                if expandedHorseID == horse.id {
                    horseControls(horse)
                }
            }
            .listRowBackground(ColorTokens.surface)
            .listRowSeparator(.hidden)
        } else {
            Section(horse.horseName) { horseControls(horse) }
                .listRowBackground(ColorTokens.surface)
        }
    }

    @ViewBuilder
    private func horseControls(_ horse: VisitHorseDraft) -> some View {
        VisitHorseOutcomeRow(
            horse: horse,
            selectableOutcomes: VisitRules.selectableOutcomes(for: model.mode),
            onOutcomeSelected: { outcome in
                guard subscription.allowsMutations else { return }
                if outcome != .serviced { focusedWorkNotesID = nil }
                _ = model.requestOutcomeChange(for: horse.id, to: outcome)
            }
        )
        .disabled(!subscription.allowsMutations)
        if horse.outcome != .notServiced { visitWorkItems(for: horse) }
        NavigationLink {
            PhotographCollectionView(
                visitHorseID: horse.id, horseName: horse.horseName, library: photographLibrary
            )
        } label: {
            metadataLayout {
                Label("Photos", systemImage: "photo.on.rectangle")
                    .accessibilityIdentifier("visit-photographs-label-\(horse.horseName)")
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: SpacingTokens.compact) }
                PhotographCountLabel(visitHorseID: horse.id, library: photographLibrary)
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .navigationLinkIndicatorVisibility(.visible)
        .accessibilityHint("View or add photos for this horse")
        .accessibilityIdentifier("visit-photographs-\(horse.horseName)")
        if horse.outcome == .serviced {
            VisitHorseNotesRow(
                note: Binding(
                    get: { model.draft?.horses.first(where: { $0.id == horse.id })?.workNotes ?? "" },
                    set: {
                        guard subscription.allowsMutations else { return }
                        model.setWorkNotes($0, for: horse.id)
                    }
                ),
                focusedHorseID: $focusedWorkNotesID,
                horseID: horse.id, horseName: horse.horseName
            )
        }
    }

    private var metadataLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SpacingTokens.compact))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: SpacingTokens.compact))
    }

    private var visitFooter: some View {
        VStack(spacing: SpacingTokens.compact) {
            VisitRecordedTotalView(total: model.savedRecordedTotal)
                .padding(.horizontal, SpacingTokens.standard)
            Group {
                if model.canComplete {
                    Button {
                        guard subscription.allowsMutations else { return }
                        focusedWorkNotesID = nil
                        if model.completeVisit(analyticsClient: analyticsClient) {
                            onCompleted?(model.visitID)
                            dismiss()
                        }
                    } label: {
                        Text("Complete Visit").frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("visit-complete")
                } else {
                    Button(action: saveProgress) {
                        Text("Save Progress").frame(maxWidth: .infinity)
                    }
                    .disabled(!model.canSaveProgress)
                    .accessibilityIdentifier("visit-save-progress")
                }
            }
            .font(.headline)
            .farrierFlowPrimaryAction()
            .controlSize(.large)
            .padding(.horizontal, SpacingTokens.standard)
            .padding(.vertical, SpacingTokens.related)
            .background(ColorTokens.background)
        }
    }

    private func saveProgress() {
        guard subscription.allowsMutations else { return }
        focusedWorkNotesID = nil
        model.saveProgress()
    }

    private func requestDeletion() {
        deletion.prepare(.scheduledVisit(model.visitID), in: context.container)
        if deletion.impact != nil { showsDiscardVisitConfirmation = true }
        else { model.alert = deletion.alert }
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
        HStack(alignment: .center) {
            Text(horse.outcome == .pending ? "Planned Services" : "Services")
                .font(Typography.recordMetadata)
                .foregroundStyle(ColorTokens.textSecondary)
            Spacer(minLength: SpacingTokens.compact)
            if subscription.allowsMutations {
                Button {
                    focusedWorkNotesID = nil
                    addServiceHorse = horse
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add Service for \(horse.horseName)")
                .accessibilityIdentifier("visit-add-service-\(horse.horseName)")
            }
        }

        if horse.workItems.isEmpty {
            Text(horse.outcome == .pending ? "No Planned Services" : "No Recorded Services")
                .foregroundStyle(ColorTokens.textSecondary)
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
                        workItemLabel(for: workItem, horse: horse)
                    }
                    .accessibilityLabel(
                        workItemAccessibilityLabel(for: workItem)
                    )
                    .accessibilityHint("Edit Service")
                    .accessibilityIdentifier(
                        "visit-work-item-\(horse.horseName)-\(workItem.serviceNameSnapshot)"
                    )
                } else {
                    workItemLabel(for: workItem, horse: horse)
                }
            }
        }

        if model.mode == .correction, horse.workItems.count > 1 {
            if let currencyCode = horse.workItems.first?.currencyCode,
               let subtotal = try? WorkItemRules.subtotal(for: horse.workItems),
               let formattedSubtotal = MoneyFormatter.currency(
                   minorUnits: subtotal,
                   currencyCode: currencyCode,
                   locale: locale
               ) {
                LabeledContent("Subtotal", value: formattedSubtotal)
                    .font(Typography.recordMetadata)
                    .monospacedDigit()
                    .accessibilityLabel("Subtotal, \(formattedSubtotal)")
                    .accessibilityIdentifier("visit-work-item-subtotal-\(horse.horseName)")
            } else {
                Text("Subtotal Unavailable")
                    .font(Typography.recordMetadata)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .accessibilityIdentifier("visit-work-item-subtotal-\(horse.horseName)")
            }
        }
    }

    private func workItemLabel(
        for workItem: WorkItemDraft,
        horse: VisitHorseDraft
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.rowContent) {
            VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                Text(workItem.serviceNameSnapshot)
                    .font(Typography.recordTitle)
                if workItem.serviceIsArchived {
                    Text("Archived")
                        .font(Typography.recordMetadata)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
            Spacer(minLength: SpacingTokens.rowContent)
            Text(formattedAmount(for: workItem))
                .font(Typography.recordMetadata)
                .foregroundStyle(ColorTokens.textSecondary)
                .monospacedDigit()
                .accessibilityIdentifier(
                    "visit-work-item-amount-\(horse.horseName)-\(workItem.serviceNameSnapshot)"
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            workItemAccessibilityLabel(for: workItem)
        )
    }

    private func workItemAccessibilityLabel(for workItem: WorkItemDraft) -> String {
        "\(workItem.serviceNameSnapshot), \(formattedAmount(for: workItem))"
    }

    private func formattedAmount(for workItem: WorkItemDraft) -> String {
        MoneyFormatter.currency(
            minorUnits: workItem.amountMinorUnits,
            currencyCode: workItem.currencyCode,
            locale: locale
        )
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

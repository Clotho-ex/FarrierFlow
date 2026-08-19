import SwiftData
import SwiftUI

struct ApplyVisitWorkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @Bindable var model: VisitEditorModel
    @State private var selectedSourceID: PersistentIdentifier?
    @State private var selectedTargetIDs: Set<PersistentIdentifier> = []

    var body: some View {
        Form {
            if sourceChoices.isEmpty {
                ContentUnavailableView {
                    Label("No Work Available", systemImage: "rectangle.on.rectangle.slash")
                } description: {
                    Text("Record a valid Service for one horse before applying work.")
                }
            } else {
                sourceSection
                if let selectedSource {
                    recordedWorkSection(for: selectedSource)
                    targetSection(for: selectedSource.id)
                }
            }
        }
        .navigationTitle("Apply Work to Horses")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                Button(confirmationTitle) {
                    applyWork()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Marks the selected horses Serviced and adds independent copies of the recorded Services.")
                .accessibilityIdentifier("visit-batch-confirm")
                .disabled(selectedTargetIDs.isEmpty)
            }
        }
        .onAppear {
            if selectedSourceID == nil {
                selectedSourceID = sourceChoices.first?.id
            }
        }
        .onChange(of: selectedSourceID) {
            selectedTargetIDs.removeAll()
        }
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
    }

    private var sourceChoices: [VisitBatchWorkSourceChoice] {
        model.batchWorkSourceChoices
    }

    private var selectedSource: VisitBatchWorkSourceChoice? {
        sourceChoices.first(where: { $0.id == selectedSourceID })
    }

    private var confirmationTitle: LocalizedStringResource {
        if selectedTargetIDs.count == 1 {
            "Apply to 1 Horse"
        } else {
            "Apply to \(selectedTargetIDs.count) Horses"
        }
    }

    private var sourceSection: some View {
        Section("Source Horse") {
            Picker("Copy Work From", selection: $selectedSourceID) {
                ForEach(sourceChoices) { source in
                    Text(source.horseName)
                        .tag(Optional(source.id))
                }
            }
            .accessibilityHint("Choose the serviced horse whose recorded Services and prices will be copied.")
            .accessibilityIdentifier("visit-batch-source")
        }
    }

    private func recordedWorkSection(
        for source: VisitBatchWorkSourceChoice
    ) -> some View {
        Section {
            ForEach(source.workItems) { workItem in
                LabeledContent(
                    workItem.serviceNameSnapshot,
                    value: formattedAmount(for: workItem)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(workItem.serviceNameSnapshot), \(formattedAmount(for: workItem))"
                )
                .accessibilityIdentifier(
                    "visit-batch-summary-\(workItem.serviceNameSnapshot)"
                )
            }
        } header: {
            Text("Recorded Work")
        } footer: {
            Text("Service names and prices are copied exactly. Work Notes and photographs are not copied.")
        }
    }

    private func targetSection(
        for sourceID: PersistentIdentifier
    ) -> some View {
        Section {
            ForEach(model.batchWorkTargetChoices(for: sourceID)) { target in
                if let violation = target.violation {
                    LabeledContent(target.horseName) {
                        Text(targetExplanation(for: violation))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("visit-batch-target-ineligible-\(target.horseName)")
                } else {
                    Toggle(isOn: targetSelection(for: target.id)) {
                        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                            Text(target.horseName)
                            Text("Not Started")
                                .font(Typography.recordMetadata)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityValue(
                        selectedTargetIDs.contains(target.id) ? "Selected" : "Not Selected"
                    )
                    .accessibilityIdentifier("visit-batch-target-\(target.horseName)")
                }
            }
        } header: {
            Text("Apply To")
        } footer: {
            Text("Horses with an outcome, Work Notes, or recorded Services are never changed.")
        }
    }

    private func targetSelection(
        for targetID: PersistentIdentifier
    ) -> Binding<Bool> {
        Binding(
            get: { selectedTargetIDs.contains(targetID) },
            set: { isSelected in
                if isSelected {
                    selectedTargetIDs.insert(targetID)
                } else {
                    selectedTargetIDs.remove(targetID)
                }
            }
        )
    }

    private func formattedAmount(for workItem: WorkItemDraft) -> String {
        MoneyFormatter.usd(minorUnits: workItem.amountMinorUnits, locale: locale)
            ?? String(localized: "Unavailable", locale: locale)
    }

    private func targetExplanation(
        for violation: VisitBatchWorkViolation
    ) -> LocalizedStringResource {
        switch violation {
        case .targetMustBePending:
            "Already has a Work Status"
        case .targetHasWorkNotes:
            "Already has Work Notes"
        case .targetHasRecordedWork:
            "Already has recorded Services"
        case .targetSelectionRequired,
             .duplicateTarget,
             .sourceSelectedAsTarget,
             .sourceHorseUnavailable,
             .sourceMustBeServiced,
             .sourceRequiresRecordedWork,
             .invalidSourceWork,
             .sourceContainsArchivedService,
             .targetHorseUnavailable,
             .invalidResult:
            "Unavailable for batch work"
        }
    }

    private func applyWork() {
        guard let selectedSourceID else { return }
        let orderedTargetIDs = model.batchWorkTargetChoices(for: selectedSourceID)
            .map(\.id)
            .filter(selectedTargetIDs.contains)
        if model.applyRecordedWork(
            from: selectedSourceID,
            to: orderedTargetIDs
        ) {
            dismiss()
        }
    }
}

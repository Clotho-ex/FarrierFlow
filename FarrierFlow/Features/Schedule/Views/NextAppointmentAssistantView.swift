import SwiftData
import SwiftUI

struct NextAppointmentAssistantView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model: NextAppointmentAssistantModel
    @State private var editorSeed: NextAppointmentSeed?
    @State private var savedAppointmentID: PersistentIdentifier?
    @State private var path: [ScheduleRoute] = []

    init(visitID: PersistentIdentifier) {
        _model = State(
            initialValue: NextAppointmentAssistantModel(visitID: visitID)
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Next Appointment")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(dismissActionTitle) {
                            dismiss()
                        }
                    }
                }
                .navigationDestination(for: ScheduleRoute.self) { route in
                    switch route {
                    case let .detail(appointmentID):
                        AppointmentDetailView(appointmentID: appointmentID)
                    }
                }
                .onAppear(perform: load)
                .sheet(
                    isPresented: editorIsPresented,
                    onDismiss: handleEditorDismissal
                ) {
                    if let editorSeed {
                        AppointmentEditorView(seed: editorSeed) { appointmentID in
                            savedAppointmentID = appointmentID
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.loadState {
        case .loading:
            ProgressView("Loading Next Appointment…")
        case .failed:
            ContentUnavailableView {
                Label("Next Appointment Unavailable", systemImage: "calendar.badge.exclamationmark")
            } description: {
                Text("The current visit and schedule couldn’t be loaded.")
            } actions: {
                Button("Retry", action: load)
            }
        case .loaded:
            if let projection = model.projection {
                loadedForm(projection)
            }
        }
    }

    private func loadedForm(_ projection: NextAppointmentAssistantProjection) -> some View {
        Form {
            Section("Visit") {
                LabeledContent("Service Location", value: projection.sourceBarnName)
                LabeledContent {
                    Text(
                        projection.sourceWorkDate,
                        format: .dateTime.month().day().year()
                    )
                } label: {
                    Text("Work Date")
                }
            }

            Section("Appointment") {
                DatePicker(
                    "Proposed Start",
                    selection: Binding(
                        get: { model.projection?.proposedStart ?? projection.proposedStart },
                        set: { proposedStart in
                            model.setProposedStart(proposedStart)
                        }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                if !projection.hasFollowUpSuggestion {
                    Text("No selected Horse has a follow-up suggestion. Choose any available start.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Horses") {
                ForEach(projection.options) { option in
                    horseRow(option)
                }
            }

            if subscription.allowsMutations, hasSelectableHorse(in: projection) {
                Section {
                    Button("Continue") {
                        editorSeed = model.makeSeed()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(model.makeSeed() == nil)
                    .accessibilityIdentifier("next-appointment-continue")
                }
            }
        }
    }

    @ViewBuilder
    private func horseRow(_ option: NextAppointmentHorseOption) -> some View {
        if option.unavailabilityReason == nil {
            Toggle(
                isOn: Binding(
                    get: { selectedState(for: option.id, fallback: option.isSelected) },
                    set: { isSelected in
                        if isSelected != selectedState(
                            for: option.id,
                            fallback: option.isSelected
                        ) {
                            model.toggleHorse(option.id)
                        }
                    }
                )
            ) {
                horseDetails(option)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(option.horseName)
            .accessibilityValue(accessibilityValue(for: option))
            .accessibilityIdentifier("next-appointment-horse-\(option.horseName)")
            .disabled(!subscription.allowsMutations)
        } else {
            horseDetails(option)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(option.horseName)
                .accessibilityValue(accessibilityValue(for: option))
                .accessibilityIdentifier("next-appointment-horse-\(option.horseName)")
        }
    }

    private func horseDetails(_ option: NextAppointmentHorseOption) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(option.horseName)
                .font(Typography.recordTitle)
            Text(outcomeText(option.outcome))
                .font(Typography.recordMetadata)
                .foregroundStyle(.secondary)
            if option.outcome == .serviced, let weeks = option.intervalWeeks {
                Text("Interval: \(AppointmentIntervalFormatter.string(weeks: weeks, locale: locale))")
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
            }
            if let suggestedStart = option.suggestedStart {
                LabeledContent {
                    Text(
                        suggestedStart,
                        format: .dateTime.month().day().year().hour().minute()
                    )
                } label: {
                    Text("Suggested")
                }
                .font(Typography.recordMetadata)
            } else if option.outcome == .serviced,
                      option.unavailabilityReason == nil {
                Text("Suggestion unavailable")
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
            }
            if let reason = option.unavailabilityReason {
                Text(unavailabilityText(reason, option: option))
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func load() {
        let projectionNow = Date.now
        model.load(
            in: context,
            now: projectionNow,
            calendar: calendar,
            locale: locale
        )
    }

    private var editorIsPresented: Binding<Bool> {
        Binding(
            get: { editorSeed != nil },
            set: { isPresented in
                if !isPresented {
                    editorSeed = nil
                }
            }
        )
    }

    private func handleEditorDismissal() {
        editorSeed = nil
        guard let savedAppointmentID else { return }
        self.savedAppointmentID = nil
        path.append(.detail(savedAppointmentID))
    }

    private var dismissActionTitle: LocalizedStringKey {
        guard case .loaded = model.loadState,
              let projection = model.projection,
              hasSelectableHorse(in: projection)
        else {
            return "Done"
        }
        return "Not Now"
    }

    private func hasSelectableHorse(
        in projection: NextAppointmentAssistantProjection
    ) -> Bool {
        projection.options.contains { $0.unavailabilityReason == nil }
    }

    private func selectedState(
        for optionID: PersistentIdentifier,
        fallback: Bool
    ) -> Bool {
        model.projection?.options.first { $0.id == optionID }?.isSelected ?? fallback
    }

    private func outcomeText(_ outcome: VisitOutcome) -> String {
        switch outcome {
        case .pending:
            return String(localized: "Pending", locale: locale)
        case .serviced:
            return String(localized: "Serviced", locale: locale)
        case .notServiced:
            return String(localized: "Not Serviced", locale: locale)
        }
    }

    private func unavailabilityText(
        _ reason: NextAppointmentHorseUnavailabilityReason,
        option: NextAppointmentHorseOption
    ) -> String {
        switch reason {
        case .alreadyScheduled:
            let date: String?
            if let scheduledAppointmentStart = option.scheduledAppointmentStart {
                date = formattedDate(scheduledAppointmentStart)
            } else {
                date = nil
            }
            let location = option.scheduledServiceLocationName
            return [String(localized: "Already Scheduled", locale: locale), date, location]
                .compactMap { $0 }
                .formatted(.list(type: .and).locale(locale))
        case .newerServicedVisit:
            return String(localized: "Newer serviced Visit recorded", locale: locale)
        case .moved:
            let location = option.currentServiceLocationName
                ?? String(localized: "another Service Location", locale: locale)
            return String(localized: "Moved to \(location)", locale: locale)
        case .clientUnavailable:
            return String(localized: "Client unavailable", locale: locale)
        case .invalidAppointmentInterval:
            return String(localized: "Appointment interval unavailable", locale: locale)
        case .invalidOutcome:
            return String(localized: "Visit outcome unavailable", locale: locale)
        case .invalidCurrentGraph:
            return String(localized: "Horse details unavailable", locale: locale)
        }
    }

    private func accessibilityValue(for option: NextAppointmentHorseOption) -> String {
        var values = [outcomeText(option.outcome)]
        if option.outcome == .serviced, let weeks = option.intervalWeeks {
            values.append(AppointmentIntervalFormatter.string(weeks: weeks, locale: locale))
        }
        if let suggestedStart = option.suggestedStart {
            values.append(
                String(localized: "Suggested \(formattedDate(suggestedStart))", locale: locale)
            )
        }
        if let reason = option.unavailabilityReason {
            values.append(unavailabilityText(reason, option: option))
        } else {
            values.append(
                selectedState(for: option.id, fallback: option.isSelected)
                    ? String(localized: "Selected", locale: locale)
                    : String(localized: "Not selected", locale: locale)
            )
        }
        return values.formatted(.list(type: .and).locale(locale))
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
                .year()
                .hour()
                .minute()
                .locale(locale)
        )
    }
}

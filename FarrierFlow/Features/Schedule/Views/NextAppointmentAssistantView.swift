import SwiftData
import SwiftUI

struct NextAppointmentAssistantView: View {
    @Environment(\.appClock) private var appClock
    @Environment(\.analyticsClient) private var analyticsClient
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.selectedAppTab) private var selectedAppTab
    @Environment(\.appointmentSaved) private var appointmentSaved
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model: NextAppointmentAssistantModel
    @State private var isScheduling = false

    init(visitID: PersistentIdentifier) {
        _model = State(
            initialValue: NextAppointmentAssistantModel(visitID: visitID)
        )
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Schedule Next Visit")
                .toolbarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: SpacingTokens.compact) {
                        if subscription.allowsMutations {
                            Button {
                                guard !isScheduling else { return }
                                isScheduling = true
                                if model.schedule(in: context, now: appClock.now(),
                                    calendar: calendar, locale: locale, analyticsClient: analyticsClient) != nil {
                                    appointmentSaved()
                                    finish()
                                } else {
                                    isScheduling = false
                                }
                            } label: {
                                Text("Schedule Next Appointment").frame(maxWidth: .infinity)
                            }
                            .font(.headline)
                            .farrierFlowPrimaryAction()
                            .controlSize(.large)
                            .disabled(isScheduling || model.makeSeed() == nil)
                            .accessibilityIdentifier("next-appointment-confirm")
                        }
                        Button("Not Now", role: .cancel, action: finish)
                            .frame(maxWidth: .infinity, minHeight: SpacingTokens.minimumTouchTarget)
                            .buttonStyle(.plain)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .accessibilityIdentifier("next-appointment-not-now")
                    }
                    .padding(.horizontal, SpacingTokens.standard)
                    .padding(.vertical, SpacingTokens.compact)
                    .background(ColorTokens.background)
                }
                .onAppear(perform: load)
                .alert(item: $model.alert) {
                    Alert(title: Text($0.title), message: Text($0.message))
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
        VStack(spacing: 0) {
            Form {
                RecordSection(Text("Visit")) {
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
                .listRowBackground(ColorTokens.surface)

                RecordSection(Text("Appointment")) {
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
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                .listRowBackground(ColorTokens.surface)

                RecordSection(Text("Horses")) {
                    ForEach(projection.options) { option in
                        horseRow(option)
                    }
                }
                .listRowBackground(ColorTokens.surface)
            }
            .farrierFlowScrollBackground()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background)
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
                .foregroundStyle(ColorTokens.textSecondary)
            if option.outcome == .serviced, let weeks = option.intervalWeeks {
                Text("Interval: \(AppointmentIntervalFormatter.string(weeks: weeks, locale: locale))")
                    .font(Typography.recordMetadata)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            if let suggestedStart = option.suggestedStart {
                if (model.projection?.options.count ?? 0) > 1 {
                    LabeledContent {
                        Text(suggestedStart, format: .dateTime.month().day().year().hour().minute())
                    } label: {
                        Text("Suggested")
                    }
                    .font(Typography.recordMetadata)
                }
            } else if option.outcome == .serviced,
                      option.unavailabilityReason == nil {
                Text("Suggestion unavailable")
                    .font(Typography.recordMetadata)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            if let reason = option.unavailabilityReason {
                Text(unavailabilityText(reason, option: option))
                    .font(Typography.recordMetadata)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
    }

    private func finish() {
        dismiss()
        selectedAppTab?.wrappedValue = .today
    }

    private func load() {
        let projectionNow = appClock.now()
        model.load(
            in: context,
            now: projectionNow,
            calendar: calendar,
            locale: locale
        )
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

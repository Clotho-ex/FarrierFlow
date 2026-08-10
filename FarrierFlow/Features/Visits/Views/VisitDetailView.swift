import SwiftData
import SwiftUI

struct VisitDetailView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(PhotographLibrary.self) private var photographLibrary
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model: VisitDetailModel
    @State private var nextAppointmentModel: NextAppointmentAssistantModel
    @State private var showsEditor = false
    @State private var showsNextAppointmentAssistant = false
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
        _nextAppointmentModel = State(
            initialValue: NextAppointmentAssistantModel(visitID: visitID)
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
                        loadVisitDetail()
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
            if subscription.allowsMutations, model.loadState == .loaded,
               (model.editorMode == .inProgress || !model.isCorrectionLocked) {
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
            loadVisitDetail()
        }
        .sheet(isPresented: $showsEditor, onDismiss: {
            loadVisitDetail()
        }) {
            VisitEditorView(
                visitID: model.visitID,
                container: modelContainer,
                mode: model.editorMode
            )
        }
        .sheet(
            isPresented: $showsNextAppointmentAssistant,
            onDismiss: reloadNextAppointmentProjection
        ) {
            NextAppointmentAssistantView(visitID: model.visitID)
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
                if detail.isCorrectionLocked {
                    Section("Invoiced Work") {
                        Text("This visit has invoiced work and can no longer be corrected.")
                            .foregroundStyle(.secondary)
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
                            .accessibilityIdentifier("visit-result-\(horse.horseName)")
                        recordedServices(for: horse)
                        hoofPhotographsLink(for: horse)
                    }
                }
                if detail.completedAt != nil {
                    Section("Visit Total") {
                        LabeledContent("Total", value: totalText(for: detail.total))
                            .accessibilityIdentifier("visit-detail-total")
                    }
                    nextAppointmentSection
                }
            }
        } else {
            ContentUnavailableView("Visit Unavailable", systemImage: "exclamationmark.circle")
        }
    }

    @ViewBuilder
    private var nextAppointmentSection: some View {
        Section("Next Appointment") {
            switch nextAppointmentModel.loadState {
            case .loading:
                HStack {
                    ProgressView()
                    Text("Loading schedule…")
                }
            case .failed:
                Text("Next Appointment Unavailable")
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    reloadNextAppointmentProjection()
                }
            case .loaded:
                if let projection = nextAppointmentModel.projection {
                    if subscription.allowsMutations, projection.options.contains(where: {
                        $0.unavailabilityReason == nil
                    }) {
                        Button("Schedule Next Appointment") {
                            showsNextAppointmentAssistant = true
                        }
                        .accessibilityIdentifier("schedule-next-appointment")
                    } else {
                        ForEach(projection.options) { option in
                            LabeledContent(
                                option.horseName,
                                value: nextAppointmentStatus(for: option)
                            )
                        }
                    }
                }
            }
        }
    }

    private func loadVisitDetail() {
        model.load(locale: locale)
        if model.detail?.completedAt != nil {
            reloadNextAppointmentProjection()
        }
    }

    private func reloadNextAppointmentProjection() {
        let projectionNow = Date.now
        nextAppointmentModel.load(
            in: context,
            now: projectionNow,
            calendar: calendar,
            locale: locale
        )
    }

    private func nextAppointmentStatus(for option: NextAppointmentHorseOption) -> String {
        guard let reason = option.unavailabilityReason else {
            return String(localized: "Available", locale: locale)
        }
        switch reason {
        case .alreadyScheduled:
            let date = option.scheduledAppointmentStart?.formatted(
                .dateTime
                    .month(.abbreviated)
                    .day()
                    .year()
                    .hour()
                    .minute()
                    .locale(locale)
            )
            return [
                String(localized: "Already Scheduled", locale: locale),
                date,
                option.scheduledServiceLocationName,
            ]
            .compactMap { $0 }
            .formatted(.list(type: .and).locale(locale))
        case .newerServicedVisit:
            return String(localized: "Newer serviced Visit recorded", locale: locale)
        case .moved:
            if let currentLocation = option.currentServiceLocationName {
                return String(localized: "Moved to \(currentLocation)", locale: locale)
            }
            return String(localized: "Moved to another Service Location", locale: locale)
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

    @ViewBuilder
    private func recordedServices(for horse: VisitHorseResult) -> some View {
        if horse.outcome != .notServiced {
            if !horse.workItems.isEmpty {
                Text("Services")
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
                ForEach(horse.workItems) { workItem in
                    if let serviceID = workItem.serviceID {
                        NavigationLink {
                            ServiceDetailView(serviceID: serviceID)
                        } label: {
                            workItemRow(workItem)
                        }
                        .accessibilityIdentifier("visit-detail-work-item-\(horse.id)-\(workItem.id)")
                    } else {
                        workItemRow(workItem)
                            .accessibilityIdentifier("visit-detail-work-item-\(horse.id)-\(workItem.id)")
                    }
                }
            }

            if horse.outcome == .serviced {
                LabeledContent("Subtotal", value: subtotalText(for: horse.subtotal))
                    .accessibilityIdentifier("visit-detail-subtotal-\(horse.horseName)")
                if horse.subtotal == .unavailable {
                    Text("No recorded services")
                        .font(Typography.recordMetadata)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("visit-detail-no-recorded-services-\(horse.horseName)")
                }
            }
        }
    }

    @ViewBuilder
    private func workItemRow(_ workItem: VisitWorkItemResult) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            HStack(alignment: .firstTextBaseline) {
                Text(workItem.serviceNameSnapshot)
                    .font(Typography.recordMetadata)
                Spacer(minLength: SpacingTokens.rowContent)
                Text(formattedAmount(workItem.amountMinorUnits))
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
            }
            if workItem.serviceIsArchived == true {
                Text("Archived")
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(workItem.serviceNameSnapshot)
        .accessibilityValue(workItemAccessibilityValue(workItem))
    }

    private func hoofPhotographsLink(for horse: VisitHorseResult) -> some View {
        NavigationLink {
            PhotographCollectionDestination(
                visitHorseID: horse.id,
                horseName: horse.horseName
            )
        } label: {
            HStack {
                Label("Hoof Photos", systemImage: "photo.on.rectangle")
                Spacer()
                PhotographCountLabel(
                    visitHorseID: horse.id,
                    library: photographLibrary
                )
            }
        }
    }

    private func subtotalText(for subtotal: MoneyAvailability) -> String {
        switch subtotal {
        case let .available(minorUnits):
            return formattedAmount(minorUnits)
        case .unavailable:
            return String(localized: "Subtotal Unavailable", locale: locale)
        }
    }

    private func totalText(for total: MoneyAvailability) -> String {
        switch total {
        case let .available(minorUnits):
            return formattedAmount(minorUnits)
        case .unavailable:
            return String(localized: "Total Unavailable", locale: locale)
        }
    }

    private func formattedAmount(_ minorUnits: Int64) -> String {
        MoneyFormatter.usd(minorUnits: minorUnits, locale: locale)
            ?? String(localized: "Unavailable", locale: locale)
    }

    private func workItemAccessibilityValue(_ workItem: VisitWorkItemResult) -> String {
        [
            formattedAmount(workItem.amountMinorUnits),
            workItem.serviceIsArchived == true ? String(localized: "Archived", locale: locale) : nil,
        ]
        .compactMap { $0 }
        .formatted(.list(type: .and).locale(locale))
    }
}

private struct PhotographCollectionDestination: View {
    @Environment(PhotographLibrary.self) private var photographLibrary
    let visitHorseID: PersistentIdentifier
    let horseName: String

    var body: some View {
        PhotographCollectionView(
            visitHorseID: visitHorseID,
            horseName: horseName,
            library: photographLibrary
        )
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

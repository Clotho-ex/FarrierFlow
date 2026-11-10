import SwiftData
import SwiftUI
import UIKit

struct VisitDetailView: View {
    @Environment(\.appClock) private var appClock
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(PhotographLibrary.self) private var photographLibrary
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.backupSync) private var backupSync
    @State private var model: VisitDetailModel
    @State private var nextAppointmentModel: NextAppointmentAssistantModel
    @State private var showsEditor = false
    @State private var showsDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var didDelete = false
    @State private var showsNextAppointmentAssistant = false
    private let showsDismissAction: Bool
    private let allowsDeletingRecordedWork: Bool

    init(
        visitID: PersistentIdentifier,
        container: ModelContainer,
        showsDismissAction: Bool = false,
        allowsDeletingRecordedWork: Bool = false
    ) {
        self.showsDismissAction = showsDismissAction
        self.allowsDeletingRecordedWork = allowsDeletingRecordedWork
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
            if subscription.allowsMutations, model.loadState == .loaded {
                if model.editorMode == .correction {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Edit", systemImage: "pencil") { showsEditor = true }
                                .accessibilityIdentifier("visit-edit-action")
                            if allowsDeletingRecordedWork || model.hasScheduledAppointment {
                                Divider()
                                deleteButton
                            }
                        } label: {
                            Label("Actions", systemImage: "ellipsis")
                        }
                        .tint(ColorTokens.textSecondary)
                        .accessibilityIdentifier("visit-detail-actions")
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        if allowsDeletingRecordedWork || model.hasScheduledAppointment {
                            deleteButton
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Resume Visit") { showsEditor = true }
                            .accessibilityIdentifier("visit-resume-action")
                    }
                }
            }
            if showsDismissAction {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("visit-detail-done")
                }
            }
        }
        .recordDeletionConfirmation(
            allowsDeletingRecordedWork ? .visit(model.visitID) : .scheduledVisit(model.visitID),
            isPresented: $showsDeleteConfirmation,
            title: allowsDeletingRecordedWork ? "Delete Recorded Work?" : "Delete Visit?",
            confirmationTitle: allowsDeletingRecordedWork ? "Delete Recorded Work" : "Delete Visit",
            accessibilityPrefix: "visit-delete", alert: $model.alert,
            isDeleting: $isDeleting
        ) {
            didDelete = true
            model.alert = nil
            dismiss()
        }
        .onAppear {
            loadVisitDetail()
        }
        .onChange(of: backupSync?.runtime?.recordsVersion) { _, _ in loadVisitDetail() }
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

    private var deleteButton: some View {
        Button(allowsDeletingRecordedWork ? LocalizedStringKey("Delete Recorded Work") : LocalizedStringKey("Delete Visit"), systemImage: "trash", role: .destructive) {
            showsDeleteConfirmation = true
        }
        .accessibilityIdentifier("visit-delete-action")
    }

    @Environment(\.modelContext) private var context

    private var modelContainer: ModelContainer {
        context.container
    }

    @ViewBuilder
    private var detailList: some View {
        if let detail = model.detail {
            List {
                visitOverview(detail)
                ForEach(detail.horses) { horse in
                    Section {
                        VisitHorseResultRow(horse: horse)
                            .accessibilityIdentifier("visit-result-\(horse.horseName)")
                        recordedServices(for: horse)
                        VisitPhotographsLink(
                            horse: horse,
                            library: photographLibrary,
                            allowsAdding: subscription.allowsMutations
                        )
                        if let notes = horse.workNotes {
                            VStack(alignment: .leading, spacing: SpacingTokens.compact) {
                                Text(horse.outcome == .notServiced ? "Reason" : "Work Notes")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(ColorTokens.textPrimary)
                                Text(verbatim: notes)
                                    .font(.body)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(SpacingTokens.related)
                                    .background(ColorTokens.noteSurface, in: .rect(cornerRadius: SpacingTokens.related))
                                    .textSelection(.enabled)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("visit-result-notes-\(horse.horseName)")
                        }
                    }
                    .listRowInsets(EdgeInsets(
                        top: SpacingTokens.compact, leading: SpacingTokens.standard,
                        bottom: SpacingTokens.compact, trailing: SpacingTokens.standard
                    ))
                    .listRowBackground(ColorTokens.surface)
                    .listRowSeparator(.hidden)
                }
                if detail.completedAt != nil, detail.horses.contains(where: { !$0.workItems.isEmpty }) {
                    Section {
                        LabeledContent("Total recorded work") {
                            Text(totalText(for: detail.total))
                                .rollingStateText(value: totalText(for: detail.total))
                        }
                        .accessibilityIdentifier("visit-detail-total")
                    }
                    .listRowBackground(ColorTokens.surface)
                    .listRowSeparator(.hidden)
                }
                invoiceSection(detail)
                if detail.completedAt != nil {
                    nextAppointmentSection
                }
            }
            .listSectionSpacing(.custom(SpacingTokens.standard))
            .farrierFlowScrollBackground()
        } else {
            ContentUnavailableView("Visit Unavailable", systemImage: "exclamationmark.circle")
        }
    }

    @ViewBuilder
    private func invoiceSection(_ detail: VisitDetail) -> some View {
        if !detail.invoices.isEmpty {
            RecordSection(Text("Invoices")) {
                ForEach(detail.invoices) { invoice in
                    RecordNavigationLink(value: InvoiceRoute.detail(invoice.id)) {
                        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                            Text("Invoice \(invoice.number)")
                                .font(Typography.recordTitle)
                            Text(invoice.clientName)
                                .font(Typography.recordMetadata)
                                .foregroundStyle(ColorTokens.textSecondary)
                            if dynamicTypeSize.isAccessibilitySize {
                                Text(invoice.status.displayName)
                                    .rollingStateText(value: invoice.status.rawValue)
                                    .font(Typography.recordMetadata)
                                    .foregroundStyle(invoice.status == .paid ? ColorTokens.success : ColorTokens.textSecondary)
                            }
                        }
                    }
                    .badge(
                        dynamicTypeSize.isAccessibilitySize ? nil : Text(invoice.status.displayName)
                            .foregroundStyle(invoice.status == .paid ? ColorTokens.success : ColorTokens.textSecondary)
                    )
                    .accessibilityIdentifier("visit-invoice-\(invoice.number)")
                }
            }
            .listRowBackground(ColorTokens.surface)
        }
    }

    private func visitOverview(_ detail: VisitDetail) -> some View {
        Section {
            locationAndStatus(detail)
            VisitWorkOverview(
                startedAt: detail.startedAt,
                completedAt: detail.completedAt
            )
            if detail.isCorrectionLocked {
                HStack(alignment: .top, spacing: SpacingTokens.compact) {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(ColorTokens.brandActionText)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                        Text("This visit has invoiced work.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text("Corrections do not change saved invoices.")
                            .font(.footnote)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("visit-invoice-warning")
            }
        }
        .listRowBackground(ColorTokens.surface)
        .listRowSeparator(.hidden)
    }

    private func locationAndStatus(_ detail: VisitDetail) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SpacingTokens.compact))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: SpacingTokens.related))
        return layout {
            Group {
                if let barnID = detail.barnID {
                    RecordNavigationLink {
                        BarnDetailView(barnID: barnID)
                    } label: {
                        locationSnapshot(detail)
                    }
                } else {
                    locationSnapshot(detail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if detail.completedAt != nil {
                CompletedStatusPill()
                    .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
                    .accessibilityIdentifier("visit-detail-status")
            }
        }
    }

    @ViewBuilder
    private var nextAppointmentSection: some View {
        RecordSection(Text("Next Appointment")) {
            switch nextAppointmentModel.loadState {
            case .loading:
                HStack {
                    ProgressView()
                    Text("Loading schedule…")
                }
            case .failed:
                Text("Next Appointment Unavailable")
                    .foregroundStyle(ColorTokens.textSecondary)
                Button("Retry") {
                    reloadNextAppointmentProjection()
                }
            case .loaded:
                if let projection = nextAppointmentModel.projection {
                    if subscription.allowsMutations, projection.options.contains(where: {
                        $0.unavailabilityReason == nil
                    }) {
                        Button {
                            showsNextAppointmentAssistant = true
                        } label: {
                            Text("Schedule Next Appointment")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity)
                        }
                        .farrierFlowPrimaryAction()
                        .controlSize(.large)
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
        .listRowBackground(ColorTokens.surface)
    }

    private func loadVisitDetail() {
        guard !isDeleting, !didDelete else { return }
        model.load(locale: locale)
        if model.detail?.completedAt != nil {
            reloadNextAppointmentProjection()
        }
    }

    private func reloadNextAppointmentProjection() {
        let projectionNow = appClock.now()
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
                .font(.title2.weight(.semibold))
            if let address = detail.serviceLocationAddressSnapshot {
                Text(address)
                    .font(Typography.recordMetadata)
                    .foregroundStyle(ColorTokens.textSecondary)
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
        ForEach(horse.workItems) { workItem in
            if let serviceID = workItem.serviceID {
                RecordNavigationLink {
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

    private func workItemRow(_ workItem: VisitWorkItemResult) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SpacingTokens.rowContent))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: SpacingTokens.rowContent))
        return VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            layout {
                Text(workItem.serviceNameSnapshot)
                    .font(Typography.recordMetadata)
                    .fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: SpacingTokens.rowContent) }
                Text(formattedAmount(
                    workItem.amountMinorUnits,
                    currencyCode: workItem.currencyCode
                ))
                    .font(Typography.recordMetadata)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            if workItem.serviceIsArchived == true {
                Text("Archived")
                    .font(Typography.recordMetadata)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(workItem.serviceNameSnapshot)
        .accessibilityValue(workItemAccessibilityValue(workItem))
    }

    private func totalText(for total: MoneyAvailability) -> String {
        switch total {
        case let .available(minorUnits):
            return formattedAmount(minorUnits, currencyCode: detailCurrencyCode)
        case .unavailable:
            return String(localized: "Total Unavailable", locale: locale)
        }
    }

    private var detailCurrencyCode: String {
        model.detail?.currencyCode ?? BusinessCurrency.unitedStatesDollar.rawValue
    }

    private func formattedAmount(
        _ minorUnits: Int64,
        currencyCode: String
    ) -> String {
        MoneyFormatter.currency(
            minorUnits: minorUnits,
            currencyCode: currencyCode,
            locale: locale
        )
            ?? String(localized: "Unavailable", locale: locale)
    }

    private func workItemAccessibilityValue(_ workItem: VisitWorkItemResult) -> String {
        [
            formattedAmount(
                workItem.amountMinorUnits,
                currencyCode: workItem.currencyCode
            ),
            workItem.serviceIsArchived == true ? String(localized: "Archived", locale: locale) : nil,
        ]
        .compactMap { $0 }
        .formatted(.list(type: .and).locale(locale))
    }
}

private struct VisitWorkOverview: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let startedAt: Date
    let completedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.compact) {
            dateRow("Started", date: startedAt)
            if let completedAt {
                dateRow("Finished", date: completedAt)
            } else {
                Text("In Progress")
                    .font(Typography.recordMetadata)
                    .foregroundStyle(ColorTokens.brandActionText)
                    .accessibilityIdentifier("visit-detail-status")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("visit-detail-work-dates")
    }

    private func dateRow(_ title: LocalizedStringKey, date: Date) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SpacingTokens.rowContent))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: SpacingTokens.related))
        return layout {
            Text(title)
                .font(.caption)
                .foregroundStyle(ColorTokens.textSecondary)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text(date, format: .dateTime.month().day().year().hour().minute())
                .font(Typography.recordMetadata)
                .foregroundStyle(ColorTokens.textPrimary)
        }
    }
}

private struct VisitPhotographsLink: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.backupSync) private var backupSync
    @State private var count: PhotographCountModel
    let horse: VisitHorseResult
    let allowsAdding: Bool

    init(horse: VisitHorseResult, library: PhotographLibrary, allowsAdding: Bool) {
        self.horse = horse
        self.allowsAdding = allowsAdding
        _count = State(initialValue: PhotographCountModel(visitHorseID: horse.id, library: library))
    }

    var body: some View {
        Group {
            // Unknown/unavailable counts retain access to the library and its recovery UI.
            if allowsAdding || count.state != .loaded(0) {
                RecordNavigationLink {
                    PhotographCollectionDestination(visitHorseID: horse.id, horseName: horse.horseName)
                } label: {
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: SpacingTokens.compact))
                        : AnyLayout(HStackLayout(spacing: SpacingTokens.compact))
                    layout {
                        Label("Photos", systemImage: "photo.on.rectangle")
                        if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                        countLabel
                            .font(.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                .accessibilityIdentifier("visit-result-photographs-\(horse.horseName)")
            }
        }
        .onAppear { count.load() }
        .onChange(of: backupSync?.runtime?.recordsVersion) { _, _ in count.load() }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.protectedDataDidBecomeAvailableNotification
        )) { _ in count.load() }
    }

    @ViewBuilder
    private var countLabel: some View {
        switch count.state {
        case .loading:
            ProgressView().accessibilityLabel("Loading photos")
        case .loaded(let value):
            Text(value, format: .number).accessibilityLabel("\(value) photos")
        case .unavailable:
            Text("Unavailable").accessibilityLabel("Photos unavailable")
        }
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

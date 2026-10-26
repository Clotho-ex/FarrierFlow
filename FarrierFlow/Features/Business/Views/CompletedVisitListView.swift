import SwiftData
import SwiftUI

struct CompletedVisitListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @State private var model = CompletedVisitListModel()
    var period: DateInterval? = nil

    var body: some View {
        Group {
            if model.loadFailed {
                ContentUnavailableView {
                    Label("Visits Unavailable", systemImage: "exclamationmark.circle")
                } description: {
                    Text("FarrierFlow couldn’t load your completed visits. Try again.")
                } actions: {
                    Button("Retry", action: reload)
                }
            } else if model.visits.isEmpty {
                ContentUnavailableView {
                    Label("No Completed Visits", systemImage: "checkmark.circle")
                } description: {
                    if period == nil { Text("Completed visits and their recorded work appear here.") }
                    else { Text("There are no completed visits in this period.") }
                }
            } else {
                List {
                    Section {
                        ForEach(model.visits) { visit in
                            RecordNavigationLink(value: period == nil ? ClientRoute.recordedWork(visit.id) : ClientRoute.visit(visit.id)) {
                                VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                                    Text(visit.locationName)
                                        .font(Typography.recordTitle)
                                    if visit.completedAt == nil {
                                        Text("In Progress")
                                            .font(Typography.recordMetadata)
                                            .foregroundStyle(ColorTokens.textSecondary)
                                    }
                                    Text(visit.horseNames.joined(separator: ", "))
                                        .font(Typography.recordMetadata)
                                        .foregroundStyle(ColorTokens.textSecondary)
                                    Text(visit.recordedAt, format: visitDateFormat)
                                        .font(Typography.recordMetadata)
                                        .foregroundStyle(ColorTokens.textSecondary)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityElement(children: .combine)
                            }
                            .accessibilityIdentifier("business-completed-visit-\(visit.id)")
                            .listRowBackground(ColorTokens.surface)
                        }
                    } header: {
                        if let period {
                            Text(period.start, format: .dateTime.month(.wide).year()).recordSectionHeading()
                        } else {
                            Text("Recorded Work").recordSectionHeading()
                        }
                    }
                }
                .farrierFlowScrollBackground()
                .refreshable { reload() }
            }
        }
        .farrierFlowScreenBackground()
        .toolbarTitleDisplayMode(.inline)
        .navigationTitle(period == nil ? "Recorded Work" : "Completed Visits")
        .onAppear(perform: reload)
        .onChange(of: locale) { _, _ in reload() }
        .onReceive(
            ModelSaveChanges.publisher(in: context.container, entities: [
                "Visit", "VisitHorse", "Horse"
            ])
        ) {
            reload()
        }
    }

    private var visitDateFormat: Date.FormatStyle {
        if period == nil {
            .dateTime.month(.abbreviated).day().year().hour().minute()
        } else {
            .dateTime.month(.abbreviated).day().hour().minute()
        }
    }

    private func reload() {
        model.load(in: context, during: period, locale: locale)
    }
}

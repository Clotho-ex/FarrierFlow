import SwiftData
import SwiftUI

struct CompletedVisitListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.backupSync) private var backupSync
    @Environment(\.locale) private var locale
    @State private var model = CompletedVisitListModel()
    let period: DateInterval

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
                    Text("There are no completed visits in this period.")
                }
            } else {
                List {
                    Section {
                        ForEach(model.visits) { visit in
                            RecordNavigationLink(value: ClientRoute.visit(visit.id)) {
                                VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                                    Text(visit.locationName)
                                        .font(Typography.recordTitle)
                                    Text(visit.horseNames.joined(separator: ", "))
                                        .font(Typography.recordMetadata)
                                        .foregroundStyle(ColorTokens.textSecondary)
                                    Text(visit.completedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
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
                        Text(period.start, format: .dateTime.month(.wide).year())
                    }
                }
                .farrierFlowScrollBackground()
                .refreshable { reload() }
            }
        }
        .farrierFlowScreenBackground()
        .navigationTitle("Completed Visits")
        .onAppear(perform: reload)
        .onChange(of: locale) { _, _ in reload() }
        .onChange(of: backupSync?.runtime?.recordsVersion) { _, _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { notification in
            guard let savedContext = notification.object as? ModelContext,
                  savedContext.container === context.container else { return }
            reload()
        }
    }

    private func reload() {
        model.load(in: context, during: period, locale: locale)
    }
}

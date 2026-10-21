import SwiftData
import SwiftUI

struct BusinessView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var context
    @Environment(\.backupSync) private var backupSync
    @Environment(\.appClock) private var appClock
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var path = NavigationPath()
    @State private var overview = BusinessOverviewModel()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    directory.labelStyle(.titleOnly)
                } else {
                    directory
                }
            }
            .navigationTitle("Business")
            .toolbarTitleDisplayMode(
                dynamicTypeSize.isAccessibilitySize ? .inline : .inlineLarge
            )
            .recordNavigationDestinations(path: $path)
            .navigationDestination(for: BusinessOverviewRoute.self) { route in
                switch route {
                case .outstandingInvoices:
                    InvoiceListView(filter: .unpaid)
                case .completedVisits(let period):
                    CompletedVisitListView(period: period)
                }
            }
        }
        .onChange(of: backupSync?.runtime?.recordsVersion) { _, _ in reload() }
        .onChange(of: calendar) { _, _ in reload() }
        .onChange(of: locale) { _, _ in reload() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { reload() } }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { notification in
            guard let savedContext = notification.object as? ModelContext,
                  savedContext.container === context.container else { return }
            reload()
        }
        .task(id: overview.summary?.month.end) {
            guard let end = overview.summary?.month.end else { return }
            let delay = end.timeIntervalSince(appClock.now())
            guard delay > 0 else { reload(); return }
            do { try await Task.sleep(for: .seconds(delay)) }
            catch { return }
            guard !Task.isCancelled else { return }
            reload()
        }
    }

    private var directory: some View {
        List {
            BusinessOverviewSection(model: overview, retry: reload) { path.append($0) }

            Section("Operations") {
                NavigationLink(value: BarnRoute.list) {
                    Label("Service Locations", systemImage: "mappin.and.ellipse")
                }
                NavigationLink(value: ServiceRoute.list) {
                    Label("Services", systemImage: "wrench.and.screwdriver")
                }
                NavigationLink(value: InvoiceRoute.list) {
                    Label("Invoices", systemImage: "doc.text")
                }
            }
            .listRowBackground(ColorTokens.surface)

            Section("Settings") {
                NavigationLink(value: BusinessProfileRoute.editor) {
                    Label("Business Profile", systemImage: "person.text.rectangle")
                }
                NavigationLink(value: SubscriptionRoute.store) {
                    Label("Subscription", systemImage: "creditcard")
                }
                NavigationLink(value: BackupSyncRoute.account) {
                    Label {
                        Text(BackupSyncCopy.title)
                    } icon: {
                        Image(systemName: "icloud")
                    }
                }
                .accessibilityIdentifier("backup-sync-open")
            }
            .listRowBackground(ColorTokens.surface)

            Section {
                NavigationLink {
                    HelpAndSupportView()
                } label: {
                    Label("Help & Support", systemImage: "questionmark.circle")
                }
                NavigationLink {
                    AboutFarrierFlowView()
                } label: {
                    Label("About FarrierFlow", systemImage: "info.circle")
                }
            } header: {
                Text("Support")
            } footer: {
                VStack(spacing: SpacingTokens.compact) {
                    Text("FarrierFlow")
                    Text(AppVersion.installed.displayText)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, SpacingTokens.standard)
                .foregroundStyle(ColorTokens.textSecondary)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("business-app-version")
            }
            .listRowBackground(ColorTokens.surface)
        }
        .listSectionSpacing(.custom(SpacingTokens.section))
        .farrierFlowScrollBackground()
        .onAppear(perform: reload)
        .refreshable { reload() }
    }

    private func reload() {
        overview.load(in: context, now: appClock.now(), calendar: calendar, locale: locale)
    }
}

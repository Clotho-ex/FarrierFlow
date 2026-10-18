import SwiftUI
import SwiftData

struct BarnListView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.backupSync) private var backupSync
    @State private var model = BarnListModel()
    @State private var showsEditor = false

    var body: some View {
        Group {
            if model.barns.isEmpty {
                ContentUnavailableView {
                    Label("No Service Locations", systemImage: "mappin.and.ellipse")
                } description: {
                    Text("Add a barn, stable, or customer stop before assigning horses.")
                } actions: {
                    if subscription.allowsMutations {
                        Button("Add Service Location", systemImage: "plus") {
                            showsEditor = true
                        }
                    }
                }
            } else {
                List {
                    Section {
                        ForEach(
                            model.barns,
                            id: \.persistentModelID
                        ) { barn in
                            RecordNavigationLink(
                                value: BarnRoute.detail(
                                    barn.persistentModelID
                                )
                            ) {
                                BarnRow(barn: barn)
                            }
                            .listRowBackground(ColorTokens.surface)
                        }
                    } header: {
                        Text(serviceLocationCountLabel)
                            .textCase(nil)
                    }
                }
                .listSectionSpacing(.custom(SpacingTokens.related))
                .farrierFlowScrollBackground()
            }
        }
        .farrierFlowScreenBackground()
        .navigationTitle("Service Locations")
        .toolbarTitleDisplayMode(
            dynamicTypeSize.isAccessibilitySize ? .inline : .inlineLarge
        )
        .toolbar {
            if subscription.allowsMutations {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Service Location", systemImage: "plus") {
                        showsEditor = true
                    }
                }
            }
        }
        .sheet(isPresented: $showsEditor, onDismiss: reload) {
            BarnEditorView()
        }
        .onAppear(perform: reload)
        .onChange(of: backupSync?.runtime?.recordsVersion) { _, _ in reload() }
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
    }

    private func reload() {
        model.load(in: context)
    }

    private var serviceLocationCountLabel: LocalizedStringKey {
        model.barns.count == 1
            ? "1 service location"
            : "\(model.barns.count) service locations"
    }
}

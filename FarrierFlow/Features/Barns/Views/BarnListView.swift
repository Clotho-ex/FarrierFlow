import SwiftUI
import SwiftData

struct BarnListView: View {
    @Environment(\.modelContext) private var context
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
                    Button("Add Service Location", systemImage: "plus") {
                        showsEditor = true
                    }
                }
            } else {
                List(model.barns, id: \.persistentModelID) { barn in
                    NavigationLink(value: BarnRoute.detail(barn.persistentModelID)) {
                        BarnRow(barn: barn)
                    }
                }
            }
        }
        .navigationTitle("Service Locations")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Service Location", systemImage: "plus") {
                    showsEditor = true
                }
            }
        }
        .sheet(isPresented: $showsEditor, onDismiss: reload) {
            BarnEditorView()
        }
        .onAppear(perform: reload)
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
    }

    private func reload() {
        model.load(in: context)
    }
}

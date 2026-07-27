import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var path = NavigationPath()
    @State private var model = TodayModel()
    @State private var showsEditor = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if model.appointments.isEmpty {
                    ContentUnavailableView {
                        Label("No appointments today", systemImage: "sun.max")
                    } description: {
                        Text("Appointments scheduled for today will appear here.")
                    } actions: {
                        Button("Schedule Appointment", systemImage: "plus") {
                            showsEditor = true
                        }
                    }
                } else {
                    List(model.appointments, id: \.persistentModelID) { appointment in
                        NavigationLink(
                            value: ScheduleRoute.detail(appointment.persistentModelID)
                        ) {
                            AppointmentRow(appointment: appointment)
                        }
                    }
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schedule Appointment", systemImage: "plus") {
                        showsEditor = true
                    }
                }
            }
            .navigationDestination(for: ScheduleRoute.self) { route in
                switch route {
                case .detail(let id):
                    AppointmentDetailView(appointmentID: id)
                }
            }
            .sheet(isPresented: $showsEditor, onDismiss: reload) {
                AppointmentEditorView()
            }
            .onAppear(perform: reload)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { reload() }
            }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
    }

    private func reload() {
        model.load(in: context, now: .now, calendar: .autoupdatingCurrent)
    }
}

#Preview("Today — Empty") {
    if let container = try? ModelContainerFactory.inMemoryTest() {
        TodayView()
            .modelContainer(container)
    } else {
        ModelContainerFailureView()
    }
}

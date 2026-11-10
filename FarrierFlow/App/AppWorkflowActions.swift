import SwiftUI

extension EnvironmentValues {
    @Entry var selectedAppTab: Binding<AppTab>? = nil
    @Entry var appointmentSaved: @MainActor () -> Void = {}
}

import SwiftUI

struct SubscriptionWelcomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsBackup = false
    var body: some View {
        NavigationStack {
            SubscriptionView(
                presentation: .standard(
                    showsManageSubscriptionButton: false
                )
            )
                .accessibilityIdentifier("subscription-welcome")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(BackupSyncCopy.restoreBusiness) { showsBackup = true }
                            .accessibilityIdentifier("backup-sync-restore")
                    }
                }
        }
        .sheet(isPresented: $showsBackup) { BackupSyncSheet().dynamicTypeSize(dynamicTypeSize) }
    }
}

import SwiftUI

struct HelpAndSupportView: View {
    var body: some View {
        List {
            Section("Get Help") {
                if let url = URL(string: "https://farrierflow.vercel.app/support/") {
                    Link(destination: url) {
                        Label("Help Center", systemImage: "questionmark.circle")
                    }
                }
                if let url = URL(string: "mailto:farrierflow.support@gmail.com") {
                    Link(destination: url) {
                        VStack(alignment: .leading, spacing: SpacingTokens.compact) {
                            Text("Contact Support")
                            Text(verbatim: "farrierflow.support@gmail.com")
                                .font(.footnote)
                                .foregroundStyle(ColorTokens.textSecondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .listRowBackground(ColorTokens.surface)

            BusinessLegalLinks()
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
        .farrierFlowScrollBackground()
    }
}

struct AboutFarrierFlowView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: SpacingTokens.related) {
                    Text("FarrierFlow")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("Plan visits, keep horse records, and manage invoices from the field.")
                        .foregroundStyle(ColorTokens.textSecondary)
                    Text(AppVersion.installed.displayText)
                        .font(.footnote)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .accessibilityIdentifier("about-app-version")
                }
            }
            .listRowBackground(ColorTokens.surface)

            BusinessLegalLinks()
        }
        .navigationTitle("About FarrierFlow")
        .navigationBarTitleDisplayMode(.inline)
        .farrierFlowScrollBackground()
    }
}

private struct BusinessLegalLinks: View {
    var body: some View {
        Section("Legal") {
            if let url = URL(string: "https://farrierflow.vercel.app/privacy/") {
                Link("Privacy Policy", destination: url)
            }
            if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                Link("Terms of Use", destination: url)
            }
        }
        .listRowBackground(ColorTokens.surface)
    }
}

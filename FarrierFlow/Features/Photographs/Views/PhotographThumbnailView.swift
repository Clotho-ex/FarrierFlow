import SwiftUI
import UIKit

struct PhotographThumbnailView: View {
    let item: PhotographItem
    let url: URL
    let position: Int
    let total: Int

    @State private var image: UIImage?
    @State private var loadFinished = false
    @State private var protectedDataIsAvailable =
        UIApplication.shared.isProtectedDataAvailable
    @State private var reloadToken = 0

    var body: some View {
        PhotographThumbnailContentView(
            image: image,
            showsUnavailableState: item.availability == .unavailable
                || (loadFinished && protectedDataIsAvailable)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photo \(position) of \(total)")
        .accessibilityValue(
            item.availability == .available
                ? "Created \(item.createdAt.formatted(date: .abbreviated, time: .shortened))"
                : "Unavailable"
        )
        .task(id: reloadToken) {
            guard item.availability == .available else {
                loadFinished = true
                return
            }
            guard protectedDataIsAvailable else { return }
            image = await PhotographImageLoader().load(
                url: url,
                maximumPixelSize: 600
            )
            protectedDataIsAvailable = UIApplication.shared.isProtectedDataAvailable
            loadFinished = protectedDataIsAvailable
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.protectedDataWillBecomeUnavailableNotification
            )
        ) { _ in
            protectedDataIsAvailable = false
            loadFinished = false
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.protectedDataDidBecomeAvailableNotification
            )
        ) { _ in
            protectedDataIsAvailable = true
            reloadToken += 1
        }
    }
}

struct PhotographThumbnailContentView: View {
    let image: UIImage?
    let showsUnavailableState: Bool

    var body: some View {
        Color.secondary.opacity(0.12)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if showsUnavailableState {
                    VStack(spacing: SpacingTokens.rowContent) {
                        Image(systemName: "photo.badge.exclamationmark")
                        Text("Unavailable")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .compositingGroup()
            .clipShape(.rect(cornerRadius: 8))
    }
}

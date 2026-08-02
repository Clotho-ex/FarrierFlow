import SwiftUI
import UIKit

struct PhotographFullImageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let item: PhotographItem
    let url: URL
    let horseName: String
    let position: Int
    let total: Int

    @State private var image: UIImage?
    @State private var loadFinished = false
    @State private var protectedDataIsAvailable =
        UIApplication.shared.isProtectedDataAvailable
    @State private var reloadToken = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel(photoAccessibilityLabel)
                } else if item.availability == .unavailable
                    || (loadFinished && protectedDataIsAvailable) {
                    ContentUnavailableView(
                        "Photo Unavailable",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text("The stored photo file is missing.")
                    )
                    .foregroundStyle(.white)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationTitle("\(horseName) · \(position) of \(total)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task(id: reloadToken) {
            guard item.availability == .available else {
                loadFinished = true
                return
            }
            guard protectedDataIsAvailable else { return }
            image = await PhotographImageLoader().load(
                url: url,
                maximumPixelSize: PhotographConstants.maximumLongestEdge
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

    private var photoAccessibilityLabel: String {
        let date = item.createdAt.formatted(
            .dateTime.month(.abbreviated).day().year()
                .hour().minute().locale(locale)
        )
        return String(
            localized: "Hoof photo for \(horseName), \(position) of \(total), created \(date)",
            locale: locale
        )
    }
}

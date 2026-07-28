#if DEBUG
import Foundation

struct UITestLaunchConfiguration {
    static let storeNameEnvironmentKey = "FARRIERFLOW_UI_TEST_STORE"
    static let cameraUnavailableEnvironmentKey =
        "FARRIERFLOW_UI_TEST_CAMERA_UNAVAILABLE"

    let storeURL: URL?
    let forcesCameraUnavailable: Bool

    init(processInfo: ProcessInfo = .processInfo) {
        forcesCameraUnavailable =
            processInfo.environment[Self.cameraUnavailableEnvironmentKey] == "1"
        guard let rawName = processInfo.environment[Self.storeNameEnvironmentKey] else {
            storeURL = nil
            return
        }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = rawName.unicodeScalars
            .filter(allowed.contains)
            .map(String.init)
            .joined()

        guard !sanitized.isEmpty else {
            storeURL = nil
            return
        }

        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        storeURL = support
            .appending(path: "UITests", directoryHint: .isDirectory)
            .appending(path: "\(sanitized).store")
    }
}
#endif

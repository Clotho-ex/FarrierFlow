import Foundation

struct InvoicePDFTemporaryFileStore {
    let directory: URL
    init(directory: URL = FileManager.default.temporaryDirectory) { self.directory = directory }
    func write(_ data: Data, number: String) throws -> URL {
        let url = directory.appending(path: "Invoice-\(number).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }
    func removeIfPresent(_ url: URL?) { guard let url else { return }; try? FileManager.default.removeItem(at: url) }
}

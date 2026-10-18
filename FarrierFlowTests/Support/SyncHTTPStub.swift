import Foundation
import Supabase
import Synchronization

nonisolated final class SyncTestAuthStorage: AuthLocalStorage {
    private let values = Mutex<[String: Data]>([:])
    func store(key: String, value: Data) throws { values.withLock { $0[key] = value } }
    func retrieve(key: String) throws -> Data? { values.withLock { $0[key] } }
    func remove(key: String) throws { values.withLock { $0.removeValue(forKey: key) } }
}

// URLProtocol requires restating its inherited unchecked conformance. Its
// callback state is protected by Mutex and never contains real credentials.
nonisolated final class SyncHTTPStub: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (Int, Data)
    private static let handler = Mutex<Handler?>(nil)

    static func configure(_ value: Handler?) { handler.withLock { $0 = value } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() { }

    override func startLoading() {
        do {
            guard let execute = Self.handler.withLock({ $0 }), let url = request.url else {
                throw StubError.unexpectedRequest
            }
            let (status, data) = try execute(request)
            guard let response = HTTPURLResponse(
                url: url, statusCode: status, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ) else { throw StubError.invalidResponse }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    static func body(of request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { throw StubError.missingBody }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var bytes = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&bytes, maxLength: bytes.count)
            if count < 0 { throw StubError.missingBody }
            if count == 0 { break }
            data.append(contentsOf: bytes.prefix(count))
        }
        return data
    }

    enum StubError: Error { case unexpectedRequest, invalidResponse, missingBody }
}

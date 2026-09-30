import Foundation

struct SavedConnection: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var name: String
    var endpoint: Endpoint
    var mode: String = "basic"
}

/// Username and password kept (Keychain only, this device only) when the user chooses
/// "Stay signed in", so an expired password session can be renewed silently.
/// Hermes' basic auth provider issues no refresh token, so this is the only way to renew.
struct SavedCredentials: Codable, Sendable {
    var username: String
    var password: String
}

/// Do not forward login bodies or cookies to a redirect target.
private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
final class HermesHTTP {
    let connection: SavedConnection
    let session: URLSession
    let socketSession: URLSession
    private let redirects = NoRedirects()
    private var token: String?
    /// In-flight silent sign-in; concurrent 401s share one attempt.
    private var reauthTask: Task<Bool, Error>?
    private static let loginPath = "/auth/password-login"

    init(_ connection: SavedConnection) {
        self.connection = connection
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 20
        c.timeoutIntervalForResource = 180
        c.urlCache = nil
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: c, delegate: redirects, delegateQueue: nil)
        let ws = URLSessionConfiguration.ephemeral
        ws.timeoutIntervalForRequest = 15
        ws.timeoutIntervalForResource = 7 * 24 * 60 * 60
        ws.urlCache = nil
        socketSession = URLSession(configuration: ws, delegate: redirects, delegateQueue: nil)
        if connection.mode == "token", let data = Keychain.read(connection.id.uuidString) { token = String(data: data, encoding: .utf8) }
        else if let data = Keychain.read(connection.id.uuidString), let cookies = try? JSONDecoder().decode([StoredCookie].self, from: data) {
            cookies.compactMap(\.cookie).forEach { session.configuration.httpCookieStorage?.setCookie($0) }
        }
    }

    func request(_ path: String, method: String = "GET", body: JSONValue? = nil, query: [URLQueryItem] = []) async throws -> JSONValue {
        do { return try await send(path, method: method, body: body, query: query) }
        catch let failure as RPCFailure where failure.code == 401 && path != Self.loginPath && connection.mode != "token" {
            // The session expired. If the user chose "Stay signed in", renew it and retry once.
            guard try await reauthenticate() else { throw failure }
            return try await send(path, method: method, body: body, query: query)
        }
    }

    private func send(_ path: String, method: String = "GET", body: JSONValue? = nil, query: [URLQueryItem] = []) async throws -> JSONValue {
        var request = URLRequest(url: connection.endpoint.url(path, query: query))
        request.httpMethod = method
        request.timeoutInterval = path.hasPrefix("/api/audio/") ? 180 : 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token") }
        if let body {
            request.httpBody = try body.data()
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw RPCFailure(String(localized: "Invalid response from Hermes.")) }
        if response.statusCode == 401 || response.statusCode == 403 {
            throw RPCFailure(path == Self.loginPath ? String(localized: "Incorrect Hermes credentials.") : String(localized: "Your Hermes session expired. Sign in again in Settings."), code: 401)
        }
        guard (200...299).contains(response.statusCode) else {
            let failure = try? JSONValue.decode(data)
            let detail = failure?["detail"].string ?? ""
            let message = detail.isEmpty ? String(localized: "Hermes responded with HTTP \(response.statusCode).") : String(detail.prefix(600))
            throw RPCFailure(response.statusCode == 429 ? String(localized: "Too many attempts. Try again in a moment.") : message, code: response.statusCode)
        }
        try persistCookies()
        return data.isEmpty ? .object([:]) : try JSONValue.decode(data)
    }

    /// Downloads a file from the Hermes server (`/api/files/download`) into a private temporary folder.
    /// Returns the local file URL, named after the server's file.
    func download(filePath: String) async throws -> URL {
        do { return try await sendDownload(filePath) }
        catch let failure as RPCFailure where failure.code == 401 && connection.mode != "token" {
            guard try await reauthenticate() else { throw failure }
            return try await sendDownload(filePath)
        }
    }

    private func sendDownload(_ filePath: String) async throws -> URL {
        var components = URLComponents(url: connection.endpoint.url("/api/files/download"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "path", value: filePath)]
        // URLComponents leaves "+" as is, which the server would read as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { throw RPCFailure(String(localized: "This file path isn’t valid.")) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        if let token { request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token") }
        let (temporary, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let response = response as? HTTPURLResponse else { throw RPCFailure(String(localized: "Invalid response from Hermes.")) }
        switch response.statusCode {
        case 200...299: break
        case 401: throw RPCFailure(String(localized: "Your Hermes session expired. Sign in again in Settings."), code: 401)
        case 403: throw RPCFailure(String(localized: "Hermes doesn’t allow downloading this file."), code: 403)
        case 404: throw RPCFailure(String(localized: "This file no longer exists on your Hermes server."), code: 404)
        case 413: throw RPCFailure(String(localized: "This file is too large to download."), code: 413)
        default:
            let detail = (try? JSONValue.decode(Data(contentsOf: temporary)))?["detail"].string ?? ""
            throw RPCFailure(detail.isEmpty ? String(localized: "Hermes responded with HTTP \(response.statusCode).") : String(detail.prefix(600)), code: response.statusCode)
        }
        try persistCookies()
        let name = response.suggestedFilename.flatMap { $0.isEmpty ? nil : $0 } ?? (filePath as NSString).lastPathComponent
        let folder = Self.downloadsFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent((name as NSString).lastPathComponent)
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }

    /// Downloaded files are only kept for previewing and sharing; the folder is cleared on launch.
    nonisolated static let downloadsFolder = FileManager.default.temporaryDirectory.appendingPathComponent("Downloads", isDirectory: true)
    nonisolated static func clearDownloads() { try? FileManager.default.removeItem(at: downloadsFolder) }

    /// Password sign-in. With `remember`, the credentials are saved to the Keychain for silent renewal;
    /// without it, any previously saved credentials are removed.
    func signIn(username: String, password: String, remember: Bool = false) async throws {
        _ = try await send(Self.loginPath, method: "POST", body: ["provider": "basic", "username": .string(username), "password": .string(password)])
        let key = Keychain.credentialsKey(connection.id)
        if remember { try Keychain.save(JSONEncoder().encode(SavedCredentials(username: username, password: password)), key: key) }
        else { Keychain.delete(key) }
    }

    /// Signs in again with saved credentials. Returns false when none are saved or they were rejected.
    private func reauthenticate() async throws -> Bool {
        if let reauthTask { return try await reauthTask.value }
        let key = Keychain.credentialsKey(connection.id)
        guard let data = Keychain.read(key), let saved = try? JSONDecoder().decode(SavedCredentials.self, from: data) else { return false }
        let task = Task { () async throws -> Bool in
            do {
                _ = try await self.send(Self.loginPath, method: "POST", body: ["provider": "basic", "username": .string(saved.username), "password": .string(saved.password)])
                return true
            } catch let failure as RPCFailure where failure.code == 401 {
                // Password changed or account revoked: forget it so we never retry with it.
                Keychain.delete(key)
                return false
            }
        }
        reauthTask = task
        defer { reauthTask = nil }
        return try await task.value
    }

    func useToken(_ value: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RPCFailure(String(localized: "Enter the Hermes session token.")) }
        token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        try Keychain.save(Data(token!.utf8), key: connection.id.uuidString)
    }

    func socketRequest() async throws -> URLRequest {
        let url: URL
        if let token { url = connection.endpoint.socket(token: token) }
        else {
            let response = try await request("/api/auth/ws-ticket", method: "POST", body: [:])
            guard !response["ticket"].string.isEmpty else { throw RPCFailure(String(localized: "Hermes didn’t provide a WebSocket ticket.")) }
            url = connection.endpoint.socket(ticket: response["ticket"].string)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        return request
    }

    private func persistCookies() throws {
        guard connection.mode != "token" else { return }
        let cookies = (session.configuration.httpCookieStorage?.cookies ?? []).map(StoredCookie.init)
        if !cookies.isEmpty { try Keychain.save(JSONEncoder().encode(cookies), key: connection.id.uuidString) }
    }

    func invalidate() { session.invalidateAndCancel(); socketSession.invalidateAndCancel() }
}

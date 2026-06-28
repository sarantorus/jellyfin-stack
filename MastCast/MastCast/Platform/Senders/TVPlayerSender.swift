import Foundation

/// Universal-player sender — the Hybrid fallback for hard codecs the native
/// receiver can't decode. The player on the TV does the decoding, so the phone
/// never transcodes.
///
/// Implemented for **Kodi** via its JSON-RPC HTTP interface (default port 8080,
/// path `/jsonrpc`). Enable it in Kodi: Settings → Services → Control → "Allow
/// remote control via HTTP". Optional HTTP Basic auth is supported.
final class TVPlayerSender: MediaSender {
    let transport: Transport = .tvPlayer

    private var endpoint: URL?
    private let username: String?
    private let password: String?
    private let session: URLSession

    init(username: String? = nil, password: String? = nil, session: URLSession = .shared) {
        self.username = username
        self.password = password
        self.session = session
    }

    func connect(to receiver: Receiver) async throws {
        guard let url = URL(string: "http://\(receiver.host):8080/jsonrpc") else {
            throw SenderError.transportFailure("Invalid Kodi host \(receiver.host)")
        }
        endpoint = url
        // Verify the control channel is actually up.
        _ = try await rpc(method: "JSONRPC.Ping", params: [:])
    }

    func load(url: URL, metadata: CastMetadata) async throws {
        _ = try await rpc(method: "Player.Open", params: ["item": ["file": url.absoluteString]])
    }

    func play() async throws {
        // PlayPause with play:true resumes; Kodi has no explicit "play" verb.
        let id = try await activePlayerID()
        _ = try await rpc(method: "Player.PlayPause", params: ["playerid": id, "play": true])
    }

    func pause() async throws {
        let id = try await activePlayerID()
        _ = try await rpc(method: "Player.PlayPause", params: ["playerid": id, "play": false])
    }

    func seek(to seconds: Double) async throws {
        let id = try await activePlayerID()
        let s = Int(seconds)
        let time: [String: Any] = ["hours": s / 3600, "minutes": (s % 3600) / 60, "seconds": s % 60, "milliseconds": 0]
        _ = try await rpc(method: "Player.Seek", params: ["playerid": id, "value": ["time": time]])
    }

    func stop() async throws {
        let id = try await activePlayerID()
        _ = try await rpc(method: "Player.Stop", params: ["playerid": id])
    }

    func disconnect() { endpoint = nil }

    // MARK: - JSON-RPC

    private func activePlayerID() async throws -> Int {
        let result = try await rpc(method: "Player.GetActivePlayers", params: [:])
        guard let players = result as? [[String: Any]],
              let id = players.first?["playerid"] as? Int else {
            throw SenderError.transportFailure("No active Kodi player")
        }
        return id
    }

    @discardableResult
    private func rpc(method: String, params: [String: Any]) async throws -> Any? {
        guard let endpoint else { throw SenderError.notConnected }

        var body: [String: Any] = ["jsonrpc": "2.0", "method": method, "id": 1]
        if !params.isEmpty { body["params"] = params }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        if let username, let password,
           let token = "\(username):\(password)".data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SenderError.transportFailure("Kodi HTTP error")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let error = json?["error"] as? [String: Any] {
            throw SenderError.transportFailure("Kodi RPC error: \(error["message"] as? String ?? "unknown")")
        }
        return json?["result"]
    }
}

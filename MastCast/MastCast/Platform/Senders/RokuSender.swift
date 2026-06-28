import Foundation

/// Roku sender via ECP (External Control Protocol, port 8060).
///
/// Roku has no generic "play this URL" ECP verb, so we launch the built-in
/// **Roku Media Player** channel (app id 2213) with the content URL as deep-link
/// parameters — the documented way to play an arbitrary URL on Roku. Transport
/// control uses ECP keypresses; precise seek isn't exposed by ECP.
final class RokuSender: MediaSender {
    let transport: Transport = .roku
    private let mediaPlayerChannel = "2213"

    private var base: URL?
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func connect(to receiver: Receiver) async throws {
        let baseString = receiver.serviceURL ?? "http://\(receiver.host):8060"
        guard let url = URL(string: baseString) else {
            throw SenderError.transportFailure("Invalid Roku host")
        }
        base = url
        _ = try await ecp("query/device-info", method: "GET")   // reachability check
    }

    func load(url: URL, metadata: CastMetadata) async throws {
        // Encode each value ourselves: URLComponents leaves `+` unescaped in
        // queries, and Roku would read `+` as a space in the media URL.
        let pairs: [(String, String)] = [
            ("t", "v"),                       // type: video
            ("u", url.absoluteString),
            ("videoName", metadata.title),
            ("videoFormat", Self.rokuFormat(mime: metadata.mimeType, url: url)),
        ]
        let query = pairs
            .map { "\($0.0)=\(Self.encode($0.1))" }
            .joined(separator: "&")
        _ = try await ecp("launch/\(mediaPlayerChannel)?\(query)", method: "POST")
    }

    /// Percent-encode a query value, escaping everything except unreserved chars
    /// (so `+`, `&`, `=`, `/`, `?` etc. are all encoded).
    private static func encode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    // ECP keypresses. Play toggles play/pause; there is no separate resume verb.
    func play()  async throws { _ = try await ecp("keypress/Play", method: "POST") }
    func pause() async throws { _ = try await ecp("keypress/Play", method: "POST") }
    func stop()  async throws { _ = try await ecp("keypress/Home", method: "POST") }

    func seek(to seconds: Double) async throws {
        // ECP exposes no absolute seek; surface honestly rather than faking it.
        throw SenderError.unsupportedOperation
    }

    func disconnect() { base = nil }

    // MARK: - ECP

    @discardableResult
    private func ecp(_ path: String, method: String) async throws -> Data {
        guard let base, let url = URL(string: path, relativeTo: base) else { throw SenderError.notConnected }
        var request = URLRequest(url: url)
        request.httpMethod = method
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SenderError.transportFailure("Roku ECP \(path) failed")
        }
        return data
    }

    private static func rokuFormat(mime: String, url: URL) -> String {
        if mime.contains("mpegurl") || url.pathExtension.lowercased() == "m3u8" { return "hls" }
        switch url.pathExtension.lowercased() {
        case "mkv": return "mkv"
        case "mov", "m4v": return "mp4"
        case "": return "mp4"
        default: return url.pathExtension.lowercased()
        }
    }
}

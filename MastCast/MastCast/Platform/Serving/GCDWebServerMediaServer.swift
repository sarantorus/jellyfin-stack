import Foundation
import GCDWebServer   // GCDWebServer. See SETUP.md.

/// Embedded HTTP server exposing remuxed / local media to receivers over the LAN.
/// Serves an output directory (HLS playlist + segments, or a progressive file)
/// with range-request support for seeking.
final class GCDWebServerMediaServer: LocalMediaServer {
    private let server = GCDWebServer()
    private let rootDir: URL
    /// LAN base URL (built from the Wi-Fi address, not `serverURL`, which can be loopback).
    private var baseURL: URL?

    /// `rootDir` is where the Remuxer writes its output (playlist + segments).
    init(rootDir: URL) {
        self.rootDir = rootDir
        try? FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
    }

    func start() throws -> URL {
        // Custom handler so we can force correct HLS Content-Types; GCDWebServer's
        // default extension map doesn't reliably set m3u8/ts types that receivers need.
        server.addHandler(forMethod: "GET",
                          pathRegex: "^/.*",
                          request: GCDWebServerRequest.self) { [weak self] request in
            guard let self else { return GCDWebServerResponse(statusCode: 500) }
            let name = (request.path as NSString).lastPathComponent
            let fileURL = self.rootDir.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return GCDWebServerResponse(statusCode: 404)
            }
            let response = GCDWebServerFileResponse(file: fileURL.path, byteRange: request.byteRange)
            response?.contentType = Self.contentType(for: fileURL.pathExtension)
            response?.cacheControlMaxAge = 0
            response?.setValue("bytes", forAdditionalHeader: "Accept-Ranges")
            return response ?? GCDWebServerResponse(statusCode: 404)
        }

        // Port 0 = pick an ephemeral free port. Bind on all interfaces so the TV can reach us.
        try server.start(options: [
            GCDWebServerOption_Port: 0,
            GCDWebServerOption_BindToLocalhost: false,
            GCDWebServerOption_AutomaticallySuspendInBackground: false,
        ])

        // Hand the TV the device's LAN IP, never 127.0.0.1.
        guard let ip = Self.wifiIPv4Address() else {
            throw SenderError.transportFailure("No Wi-Fi network address; connect to Wi-Fi")
        }
        let port = server.port
        guard let url = URL(string: "http://\(ip):\(port)/") else {
            throw SenderError.transportFailure("Could not build local server URL")
        }
        baseURL = url
        return url
    }

    func serve(item: ServedItem) -> URL {
        let fileURL: URL
        switch item.kind {
        case .hlsPlaylist(let u): fileURL = u
        case .progressiveFile(let u): fileURL = u
        }
        // The Remuxer writes into rootDir; expose by filename relative to the base URL.
        let base = baseURL ?? URL(string: "http://127.0.0.1/")!
        return base.appendingPathComponent(fileURL.lastPathComponent)
    }

    func stop() {
        server.stop()
        baseURL = nil
    }

    // MARK: - Helpers

    private static func contentType(for ext: String) -> String {
        switch ext.lowercased() {
        case "m3u8": return "application/vnd.apple.mpegurl"
        case "ts": return "video/mp2t"
        case "mp4", "m4s": return "video/mp4"
        case "webm": return "video/webm"
        default: return "application/octet-stream"
        }
    }

    /// First non-loopback IPv4 address on the Wi-Fi interface (en0).
    private static func wifiIPv4Address() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let family = interface.ifa_addr.pointee.sa_family
            guard family == UInt8(AF_INET) else { continue }            // IPv4 only
            let name = String(cString: interface.ifa_name)
            guard name == "en0" else { continue }                       // Wi-Fi
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
            address = String(cString: hostname)
            break
        }
        return address
    }
}

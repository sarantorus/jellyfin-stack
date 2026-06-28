import Foundation
import GCDWebServer   // GCDWebServer. See SETUP.md.

/// Embedded HTTP server exposing remuxed / local media to receivers over the LAN.
/// Serves an output directory (HLS playlist + segments, or a progressive file)
/// with range-request support for seeking.
final class GCDWebServerMediaServer: LocalMediaServer {
    private let server = GCDWebServer()
    private let rootDir: URL
    private var baseURL: URL?

    /// `rootDir` is where the Remuxer writes its output (playlist + segments).
    init(rootDir: URL) {
        self.rootDir = rootDir
        try? FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
    }

    func start() throws -> URL {
        server.addGETHandler(forBasePath: "/",
                             directoryPath: rootDir.path,
                             indexFilename: nil,
                             cacheAge: 0,
                             allowRangeRequests: true)
        // Port 0 = pick an ephemeral free port. Bind on all interfaces so the TV can reach us.
        try server.start(options: [
            GCDWebServerOption_Port: 0,
            GCDWebServerOption_BindToLocalhost: false,
            GCDWebServerOption_AutomaticallySuspendInBackground: false,
        ])
        guard let url = server.serverURL else { throw SenderError.transportFailure("Local server failed to start") }
        baseURL = url
        return url
    }

    func serve(item: ServedItem) -> URL {
        let base = baseURL ?? URL(string: "http://127.0.0.1/")!
        let fileURL: URL
        switch item.kind {
        case .hlsPlaylist(let u): fileURL = u
        case .progressiveFile(let u): fileURL = u
        }
        // The Remuxer writes into rootDir; expose by filename relative to the base URL.
        return base.appendingPathComponent(fileURL.lastPathComponent)
    }

    func stop() {
        server.stop()
        baseURL = nil
    }
}

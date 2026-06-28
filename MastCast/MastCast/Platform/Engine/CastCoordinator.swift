import Foundation
import Combine

/// End-to-end orchestrator for the Cast path:
///   discover → probe source → plan → (direct | remux) → load on receiver.
/// Observable so SwiftUI can show the live receiver list, status, and the chosen
/// plan ("Direct" / "Remuxing" / "Routed to …").
@MainActor
final class CastCoordinator: ObservableObject {

    @Published private(set) var receivers: [Receiver] = []
    @Published private(set) var status: Status = .idle
    @Published private(set) var planDescription: String?

    enum Status: Equatable {
        case idle, discovering, probing, casting, playing
        case failed(String)
    }

    private let discovery: DiscoveryManager
    private let probe: MediaProbe
    private let serverRootDir: URL
    private var sender: MediaSender?
    private var localServer: LocalMediaServer?
    private var remuxer: Remuxer?

    init(discovery: DiscoveryManager = CompositeDiscovery(),
         probe: MediaProbe = FFprobeMediaProbe(),
         serverRootDir: URL = FileManager.default.temporaryDirectory.appendingPathComponent("mastcast-serve")) {
        self.discovery = discovery
        self.probe = probe
        self.serverRootDir = serverRootDir
        self.discovery.onChange = { [weak self] devices in
            Task { @MainActor in self?.receivers = devices }
        }
    }

    func startDiscovery() {
        status = .discovering
        discovery.startDiscovery()
    }

    func stopDiscovery() { discovery.stopDiscovery() }

    /// Cast `urlString` (web stream or local file path) to `receiver`.
    func cast(_ urlString: String, to receiver: Receiver, title: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        // Resolve a local file first: a bare path like "/var/.../movie.mkv" also
        // parses as a schemeless URL, which would be mislabeled as remote.
        let resolved: URL?
        if let local = localFileURL(trimmed) {
            resolved = local
        } else if let parsed = URL(string: trimmed), parsed.scheme != nil {
            resolved = parsed
        } else {
            resolved = nil
        }
        guard let url = resolved else {
            status = .failed("Invalid URL or file path"); return
        }
        let source = MediaSource(url: url)

        do {
            status = .probing
            let info = try await probe.probe(source)

            let planner = PlaybackPlanner(availableReceivers: receivers)
            let plan = planner.plan(source: info, sourceURL: url, target: receiver)
            planDescription = describe(plan)

            status = .casting
            switch plan {
            case .direct(let directURL):
                try await load(on: receiver, url: directURL,
                               mime: mimeType(forContainer: info.container), title: title)

            case .remux(let audio):
                let served = try await remuxAndServe(source: url, plan: .remux(audio: audio))
                try await load(on: receiver, url: served.url, mime: served.mime, title: title)

            case .routeToPlayer(let player):
                // The universal player decodes natively, so hand it the source
                // untouched (remote URL pass-through, or local file served raw).
                let (playerURL, mime) = try await sourceForPlayer(url, container: info.container)
                try await load(on: player, url: playerURL, mime: mime, title: title)

            case .transcode:
                status = .failed("On-phone transcode required (no universal player found) — not enabled in MVP")
                return

            case .unsupported(let reason):
                status = .failed(reason); return
            }

            status = .playing
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func stop() async {
        try? await sender?.stop()
        sender?.disconnect()
        sender = nil
        localServer?.stop(); localServer = nil
        remuxer?.cancel(); remuxer = nil
        status = .idle
    }

    // MARK: - Steps

    /// Dispatch to the correct sender for the receiver's transport.
    private func load(on receiver: Receiver, url: URL, mime: String, title: String) async throws {
        let s = SenderFactory.make(for: receiver)
        sender = s
        try await s.connect(to: receiver)
        try await s.load(url: url, metadata: CastMetadata(title: title, subtitle: nil, artworkURL: nil, mimeType: mime))
        try await s.play()
    }

    private func remuxAndServe(source: URL, plan: PlaybackPlan) async throws -> (url: URL, mime: String) {
        let server = GCDWebServerMediaServer(rootDir: serverRootDir)
        let remux = FFmpegRemuxer()
        localServer = server
        remuxer = remux
        _ = try server.start()
        let item = try await remux.remux(source: source, plan: plan, into: serverRootDir)
        return (server.serve(item: item), item.mimeType)
    }

    /// For `.routeToPlayer`: a universal player decodes any codec, so no remux is
    /// needed. Remote URLs pass through; local files are served raw over the LAN.
    private func sourceForPlayer(_ url: URL, container: String) async throws -> (URL, String) {
        let mime = mimeType(forContainer: container)
        guard url.isFileURL else { return (url, mime) }
        let server = GCDWebServerMediaServer(rootDir: url.deletingLastPathComponent())
        localServer = server
        _ = try server.start()
        let served = server.serve(item: ServedItem(kind: .progressiveFile(url), mimeType: mime))
        return (served, mime)
    }

    // MARK: - Helpers

    private func localFileURL(_ s: String) -> URL? {
        let path = s.hasPrefix("file://") ? String(s.dropFirst(7)) : s
        return FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
    }

    private func mimeType(forContainer container: String) -> String {
        switch container {
        case "mp4", "mov": return "video/mp4"
        case "webm": return "video/webm"
        case "mpegts": return "video/mp2t"
        default: return "video/mp4"
        }
    }

    private func describe(_ plan: PlaybackPlan) -> String {
        switch plan {
        case .direct: return "Direct — TV streams it; phone idle"
        case .remux(let a): return a == .copy ? "Remuxing (copy)" : "Remuxing (audio → AAC)"
        case .routeToPlayer(let r): return "Routed to \(r.name)"
        case .transcode: return "Transcoding on phone (last resort)"
        case .unsupported: return "Unsupported"
        }
    }
}

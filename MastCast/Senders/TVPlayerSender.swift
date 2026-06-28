import Foundation

/// Universal-player sender — the Hybrid fallback for hard codecs the native
/// receiver can't decode. The player on the TV does the decoding, so the phone
/// never transcodes.
///
/// Implementation note (per app):
/// - Kodi: JSON-RPC over HTTP on :8080 — `Player.Open` with `{"item":{"file": url}}`;
///   controls via `Player.PlayPause`, `Player.Seek`, `Player.Stop`.
/// - Jellyfin client: session "Play" command through the server's session API.
/// - VLC (mobile/HTTP): the HTTP requests interface, or its REST control.
/// Capability for this receiver is `.universalPlayer`, so the planner routes the
/// original URL here untouched whenever possible.
final class TVPlayerSender: MediaSender {
    let transport: Transport = .tvPlayer

    func connect(to receiver: Receiver) async throws { /* TODO: open control channel (Kodi JSON-RPC, etc.) */ }
    func load(url: URL, metadata: CastMetadata) async throws { /* TODO: Player.Open */ }
    func play() async throws { /* TODO */ }
    func pause() async throws { /* TODO */ }
    func seek(to seconds: Double) async throws { /* TODO */ }
    func stop() async throws { /* TODO */ }
    func disconnect() { /* TODO */ }
}

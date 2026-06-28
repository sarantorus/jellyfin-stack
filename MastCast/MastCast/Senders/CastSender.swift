import Foundation

/// Google Cast sender (Chromecast, Android TV, Google TV).
///
/// Implementation note: wrap the google-cast-sdk.
/// - `GCKCastContext.sharedInstance()` configured with the default receiver app ID
///   (CC1AD845) for media playback.
/// - `load` builds a `GCKMediaInformation` with the served URL + `GCKMediaMetadata`
///   (title/subtitle/artwork) and calls `remoteMediaClient.loadMedia(...)`.
/// - Transport controls map to `GCKRemoteMediaClient` play/pause/seek/stop.
final class CastSender: MediaSender {
    let transport: Transport = .googleCast

    func connect(to receiver: Receiver) async throws { /* TODO: GCKSessionManager.startSession */ }
    func load(url: URL, metadata: CastMetadata) async throws { /* TODO: loadMedia */ }
    func play() async throws { /* TODO */ }
    func pause() async throws { /* TODO */ }
    func seek(to seconds: Double) async throws { /* TODO */ }
    func stop() async throws { /* TODO */ }
    func disconnect() { /* TODO: endSession */ }
}

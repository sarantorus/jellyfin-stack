import Foundation

/// AirPlay sender (Apple TV + AirPlay 2 smart TVs).
///
/// Implementation note: AirPlay is OS-provided — we don't reimplement the protocol.
/// - Drive an `AVPlayer` and present route selection via `AVRoutePickerView`
///   (or `MPVolumeView`'s route button) so the user picks the AirPlay receiver.
/// - `load` sets `AVPlayerItem(url:)` to the served/direct URL; system handles streaming.
/// - For programmatic targeting use `AVAudioSession`/route APIs; arbitrary
///   non-UI device selection is restricted by iOS, so the picker is the supported path.
final class AirPlaySender: MediaSender {
    let transport: Transport = .airplay

    func connect(to receiver: Receiver) async throws { /* TODO: present route picker / select route */ }
    func load(url: URL, metadata: CastMetadata) async throws { /* TODO: AVPlayerItem */ }
    func play() async throws { /* TODO: player.play() */ }
    func pause() async throws { /* TODO: player.pause() */ }
    func seek(to seconds: Double) async throws { /* TODO: player.seek */ }
    func stop() async throws { /* TODO */ }
    func disconnect() { /* TODO */ }
}

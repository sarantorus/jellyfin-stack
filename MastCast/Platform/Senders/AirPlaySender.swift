import Foundation
import AVKit
import AVFoundation

/// AirPlay sender (Apple TV + AirPlay 2 smart TVs).
///
/// AirPlay is OS-provided — we don't reimplement the protocol. **iOS exposes no
/// public API to programmatically route playback to a *specific* AirPlay device**;
/// the user selects the receiver through the system route picker. So `connect(to:)`
/// is a no-op marker and the UI must present `routePickerView()` for the user to
/// pick the target. Once a route is active, `AVPlayer` streams to it.
@MainActor
final class AirPlaySender: NSObject, MediaSender {
    nonisolated let transport: Transport = .airplay

    private(set) var player: AVPlayer?

    func connect(to receiver: Receiver) async throws {
        // No programmatic device targeting on iOS — selection is via the picker.
        // Configure the audio session so external playback is allowed.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func load(url: URL, metadata: CastMetadata) async throws {
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.allowsExternalPlayback = true
        p.usesExternalPlaybackWhileExternalScreenIsActive = true
        player = p
    }

    func play()  async throws { player?.play() }
    func pause() async throws { player?.pause() }
    func stop()  async throws { player?.pause(); player?.replaceCurrentItem(with: nil) }

    func seek(to seconds: Double) async throws {
        await player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    nonisolated func disconnect() {
        Task { @MainActor in
            player?.pause()
            player = nil
        }
    }

    /// The view the UI should display so the user can pick an AirPlay receiver.
    func routePickerView() -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = true
        return picker
    }
}

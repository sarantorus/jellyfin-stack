import Foundation

/// How AnyCast will get `MediaInfo` playing on a `Receiver`.
/// Ordered cheapest → most expensive. See ARCHITECTURE.md §4.
enum PlaybackPlan: Equatable {
    /// Step 1 — hand the receiver the original remote URL; phone stays idle.
    case direct(url: URL)

    /// Step 2 — repackage container/audio on the phone (video stream copied,
    /// no re-encode), serve via the local HLS server, cast that URL.
    case remux(audio: AudioHandling)

    /// Step 3 — the native receiver can't decode this, but a universal player
    /// (Kodi/VLC/Infuse/Jellyfin) is on the network. Route playback there; it
    /// decodes natively, so the phone never transcodes.
    case routeToPlayer(receiver: Receiver)

    /// Step 4 — last resort: re-encode video on the phone. Flagged expensive;
    /// only reached when no universal player exists.
    case transcode(profile: EncodeProfile, warning: PlanWarning)

    /// We cannot play this here (e.g. DRM with no compatible direct path).
    case unsupported(reason: String)
}

enum AudioHandling: Equatable {
    case copy            // audio codec already accepted — copy through
    case reencodeAAC     // re-encode to AAC (cheap, unlike video)
}

enum EncodeProfile: Equatable {
    case h264_8bit       // safe lowest-common-denominator for old receivers
    case hevc_10bit      // when target supports it but source container/codec is exotic (e.g. AV1)
}

enum PlanWarning: Equatable {
    case expensiveOnPhone   // sustained high-bitrate re-encode may overheat / drain battery
}

struct PlaybackPlanner {

    /// All receivers currently on the network (used to find a universal-player
    /// fallback for Hybrid mode).
    let availableReceivers: [Receiver]

    func plan(source: MediaInfo, sourceURL: URL, target: Receiver) -> PlaybackPlan {
        if source.isDRMProtected {
            // DRM streams cannot be remuxed/transcoded. Only a direct hand-off
            // to a receiver that can satisfy the DRM would work.
            return canDirect(source, target)
                ? .direct(url: sourceURL)
                : .unsupported(reason: "DRM-protected content cannot be remuxed or transcoded.")
        }

        let caps = target.capabilities
        let videoOK = caps.videoCodecs.contains(source.videoCodec) && source.bitDepth <= caps.maxBitDepth
        let audioOK = caps.audioCodecs.contains(source.audioCodec)
        // Direct play requires the receiver to natively accept the *actual*
        // container. HLS support does NOT mean it can fetch-and-demux a raw MKV —
        // that only enables remuxing into HLS (step 2).
        let containerDirectOK = caps.containers.contains(source.container)
        let containerRemuxOK = caps.supportsHLS || caps.containers.contains("mp4")

        // Step 1 — fully compatible remote URL the receiver can fetch itself.
        if videoOK && audioOK && containerDirectOK && source.isRemote && caps.canFetchRemote {
            return .direct(url: sourceURL)
        }

        // Step 2 — video is fine; only the container/subs/audio need fixing.
        // Remux requires either HLS support or a container we can repackage into
        // that the target accepts.
        if videoOK && containerRemuxOK {
            return .remux(audio: audioOK ? .copy : .reencodeAAC)
        }

        // Step 3 — the native receiver can't decode the video. Route to a
        // universal player if one exists (Hybrid mode). Don't route to the
        // target itself if it's already a universal player that somehow failed
        // the checks above.
        if let player = bestUniversalPlayer(excluding: target) {
            return .routeToPlayer(receiver: player)
        }

        // Step 4 — last resort: re-encode on the phone.
        let profile: EncodeProfile = (caps.videoCodecs.contains("hevc") && caps.maxBitDepth >= 10)
            ? .hevc_10bit : .h264_8bit
        return .transcode(profile: profile, warning: .expensiveOnPhone)
    }

    // MARK: - Helpers

    private func canDirect(_ source: MediaInfo, _ target: Receiver) -> Bool {
        let c = target.capabilities
        // DRM can't be remuxed, so the container must be natively accepted —
        // HLS support is irrelevant here (it would require a remux we can't do).
        return c.canFetchRemote && source.isRemote &&
            c.videoCodecs.contains(source.videoCodec) &&
            source.bitDepth <= c.maxBitDepth &&
            c.audioCodecs.contains(source.audioCodec) &&
            c.containers.contains(source.container)
    }

    /// Pick the best universal player on the network (prefer one on the same
    /// host as the target TV, so playback lands on the right screen).
    private func bestUniversalPlayer(excluding target: Receiver) -> Receiver? {
        let players = availableReceivers.filter { $0.isUniversalPlayer && $0.id != target.id }
        return players.first { $0.host == target.host } ?? players.first
    }
}

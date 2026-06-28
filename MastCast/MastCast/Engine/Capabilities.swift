import Foundation

/// What a receiver can decode/play. Static profiles are refined at runtime
/// (e.g. by querying a Chromecast's model, or a Cast media status).
struct Capabilities: Equatable {
    var containers: Set<String>
    var videoCodecs: Set<String>
    var audioCodecs: Set<String>
    var maxBitDepth: Int
    var supportsHLS: Bool
    /// Can the receiver fetch an arbitrary internet URL itself (phone stays out of the data path)?
    var canFetchRemote: Bool
    /// Kodi / VLC / Infuse / Jellyfin — decodes essentially everything natively.
    var isUniversalPlayer: Bool
}

extension Capabilities {
    /// Apple TV / AirPlay 2 receivers.
    static let airplay = Capabilities(
        containers: ["mp4", "mov", "m4v", "mpegts"],
        videoCodecs: ["h264", "hevc"],
        audioCodecs: ["aac", "ac3", "eac3"],
        maxBitDepth: 10,
        supportsHLS: true,
        canFetchRemote: true,
        isUniversalPlayer: false)

    /// Baseline Chromecast (e.g. 3rd gen, 1080p): no HEVC, 8-bit only.
    static let chromecastBaseline = Capabilities(
        containers: ["mp4", "webm"],
        videoCodecs: ["h264", "vp8", "vp9"],
        audioCodecs: ["aac", "opus", "vorbis", "mp3"],
        maxBitDepth: 8,
        supportsHLS: true,
        canFetchRemote: true,
        isUniversalPlayer: false)

    /// Chromecast Ultra / Google TV 4K: adds HEVC, 10-bit, AC3/EAC3.
    static let chromecast4K = Capabilities(
        containers: ["mp4", "webm", "mkv"],
        videoCodecs: ["h264", "vp8", "vp9", "hevc", "av1"],
        audioCodecs: ["aac", "opus", "vorbis", "mp3", "ac3", "eac3"],
        maxBitDepth: 10,
        supportsHLS: true,
        canFetchRemote: true,
        isUniversalPlayer: false)

    /// Most conservative real-world DLNA smart TV.
    static let dlnaGeneric = Capabilities(
        containers: ["mp4"],
        videoCodecs: ["h264"],
        audioCodecs: ["aac", "ac3"],
        maxBitDepth: 8,
        supportsHLS: false,
        canFetchRemote: true,
        isUniversalPlayer: false)

    /// Kodi / VLC / Infuse / Jellyfin client — the Hybrid fallback target.
    static let universalPlayer = Capabilities(
        containers: ["mkv", "mp4", "mov", "webm", "mpegts", "avi", "ts", "m2ts"],
        videoCodecs: ["h264", "hevc", "av1", "vp9", "vp8", "mpeg2video", "vc1"],
        audioCodecs: ["aac", "ac3", "eac3", "dts", "truehd", "opus", "flac", "mp3", "vorbis"],
        maxBitDepth: 10,
        supportsHLS: true,
        canFetchRemote: true,
        isUniversalPlayer: true)
}

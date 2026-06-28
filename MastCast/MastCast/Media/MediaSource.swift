import Foundation

/// A thing the user wants to cast: a remote stream URL or a local file.
struct MediaSource: Equatable {
    let url: URL
    /// `true` for an http(s) URL the TV could fetch itself; `false` for a local file.
    var isRemote: Bool { url.isFileURL == false }
}

/// Result of probing a `MediaSource` (via ffprobe). All codec/container names are
/// lowercased canonical tokens, matching `Capabilities`.
struct MediaInfo: Equatable {
    var container: String      // "mkv", "mp4", "mov", "webm", "mpegts", ...
    var videoCodec: String     // "h264", "hevc", "av1", "vp9", ...
    var audioCodec: String     // "aac", "ac3", "eac3", "dts", "truehd", ...
    var bitDepth: Int          // 8 or 10
    var isRemote: Bool
    var isDRMProtected: Bool = false

    static func == (l: MediaInfo, r: MediaInfo) -> Bool {
        l.container == r.container && l.videoCodec == r.videoCodec &&
        l.audioCodec == r.audioCodec && l.bitDepth == r.bitDepth &&
        l.isRemote == r.isRemote && l.isDRMProtected == r.isDRMProtected
    }
}

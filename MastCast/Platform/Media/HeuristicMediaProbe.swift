import Foundation

/// A no-dependency `MediaProbe` that guesses from the file extension. Used when
/// ffmpeg-kit isn't bundled, so the app builds and runs out of the box.
///
/// It can't read real codecs, so it assumes broadly-compatible H.264/AAC 8-bit.
/// That makes MP4/HLS links direct-cast and lets MKV route to a universal player
/// (Kodi/VLC); exotic files may misroute until ffmpeg-kit is added for real
/// probing (see `FFprobeMediaProbe`).
final class HeuristicMediaProbe: MediaProbe {
    func probe(_ source: MediaSource) async throws -> MediaInfo {
        let container: String
        switch source.url.pathExtension.lowercased() {
        case "mkv":               container = "mkv"
        case "webm":              container = "webm"
        case "mov", "m4v", "mp4": container = "mp4"
        case "ts", "m2ts", "mts": container = "mpegts"
        default:                  container = "mp4"   // incl. m3u8 / extensionless
        }
        return MediaInfo(
            container: container,
            videoCodec: "h264",
            audioCodec: "aac",
            bitDepth: 8,
            isRemote: source.isRemote)
    }
}

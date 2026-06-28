import Foundation
import ffmpegkit   // ffmpeg-kit-ios (FFprobeKit). See SETUP.md for the dependency.

/// Concrete `MediaProbe` backed by ffprobe (ffmpeg-kit). Works for both local
/// files and remote URLs; for remote it reads only the header/early packets so
/// it does not download the whole stream.
final class FFprobeMediaProbe: MediaProbe {

    func probe(_ source: MediaSource) async throws -> MediaInfo {
        let path = source.isRemote ? source.url.absoluteString : source.url.path

        let info: MediaInformation? = await withCheckedContinuation { cont in
            FFprobeKit.getMediaInformationAsync(path) { session in
                cont.resume(returning: (session as? MediaInformationSession)?.getMediaInformation())
            }
        }
        guard let info else { throw ProbeError.unreadable }

        let container = normalizeContainer(info.getFormat())
        let streams = info.getStreams() ?? []

        guard let video = streams.first(where: { $0.getType() == "video" }) else {
            throw ProbeError.noVideoStream
        }
        let audio = streams.first(where: { $0.getType() == "audio" })

        return MediaInfo(
            container: container,
            videoCodec: normalize(video.getCodec()),
            audioCodec: normalize(audio?.getCodec()),
            bitDepth: bitDepth(of: video),
            isRemote: source.isRemote,
            isDRMProtected: false   // ffprobe can't detect DRM; set upstream if known
        )
    }

    // MARK: - Parsing helpers

    /// ffprobe reports container as e.g. "matroska,webm" or "mov,mp4,m4a,3gp,...".
    /// Reduce to a single canonical token the capability profiles use.
    private func normalizeContainer(_ raw: String?) -> String {
        guard let raw = raw?.lowercased() else { return "" }
        if raw.contains("matroska") { return "mkv" }
        if raw.contains("webm") { return "webm" }
        if raw.contains("mp4") || raw.contains("mov") { return "mp4" }
        if raw.contains("mpegts") || raw == "ts" { return "mpegts" }
        return raw.split(separator: ",").first.map(String.init) ?? raw
    }

    private func normalize(_ codec: String?) -> String {
        guard let c = codec?.lowercased() else { return "" }
        switch c {
        case "h265": return "hevc"
        case "ac-3": return "ac3"
        case "e-ac-3", "eac-3": return "eac3"
        default: return c
        }
    }

    /// Derive bit depth from pix_fmt (e.g. "yuv420p10le" -> 10), default 8.
    private func bitDepth(of stream: StreamInformation) -> Int {
        let pixFmt = (stream.getAllProperties()?["pix_fmt"] as? String)?.lowercased() ?? ""
        if pixFmt.contains("12le") || pixFmt.contains("12be") { return 12 }
        if pixFmt.contains("10le") || pixFmt.contains("10be") { return 10 }
        return 8
    }
}

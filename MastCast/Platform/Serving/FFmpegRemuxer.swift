import Foundation
import ffmpegkit   // ffmpeg-kit-ios (FFmpegKit). See SETUP.md.

/// Concrete `Remuxer` — repackages the source into HLS, copying the video stream
/// verbatim (no re-encode). Audio is copied when already accepted, otherwise
/// re-encoded to AAC (cheap relative to video). This covers the common
/// "MKV/H.264 + AC3/DTS" case that native receivers reject.
final class FFmpegRemuxer: Remuxer {
    private var activeSessionId: Int?

    func remux(source: URL, plan: PlaybackPlan, into outputDir: URL) async throws -> ServedItem {
        guard case let .remux(audio) = plan else {
            throw SenderError.unsupportedOperation
        }
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let playlist = outputDir.appendingPathComponent("index.m3u8")
        let segmentPattern = outputDir.appendingPathComponent("seg_%03d.ts").path
        let input = source.isFileURL ? source.path : source.absoluteString
        let audioArgs = (audio == .copy) ? "-c:a copy" : "-c:a aac -b:a 256k"

        // Copy video, fix audio, segment to HLS (event playlist = grows as we encode).
        let command = """
        -i "\(input)" -c:v copy \(audioArgs) -sn \
        -f hls -hls_time 6 -hls_playlist_type event \
        -hls_segment_filename "\(segmentPattern)" "\(playlist.path)"
        """

        let returnCode: ReturnCode? = await withCheckedContinuation { cont in
            let session = FFmpegKit.executeAsync(command) { session in
                cont.resume(returning: (session as? FFmpegSession)?.getReturnCode())
            }
            activeSessionId = (session as? FFmpegSession)?.getSessionId()?.intValue
        }

        guard let rc = returnCode, ReturnCode.isSuccess(rc) else {
            throw SenderError.transportFailure("Remux failed (ffmpeg)")
        }
        return ServedItem(kind: .hlsPlaylist(playlist), mimeType: "application/x-mpegURL")
    }

    func cancel() {
        if let id = activeSessionId { FFmpegKit.cancel(id) }
    }
}

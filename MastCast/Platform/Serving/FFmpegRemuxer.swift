import Foundation
import ffmpegkit   // ffmpeg-kit-ios (FFmpegKit). See SETUP.md.

/// Concrete `Remuxer` — repackages the source into HLS, copying the video stream
/// verbatim (no re-encode). Audio is copied when already accepted, otherwise
/// re-encoded to AAC (cheap relative to video). This covers the common
/// "MKV/H.264 + AC3/DTS" case that native receivers reject.
///
/// Uses the argument-array API (`executeAsyncWithArguments`) rather than a single
/// command string, so paths with spaces need no shell-style quoting.
final class FFmpegRemuxer: Remuxer {
    /// Serializes access to `sessionId` across the ffmpeg callback thread and `cancel()`.
    private let lock = NSLock()
    private var sessionId: Int?

    func remux(source: URL, plan: PlaybackPlan, into outputDir: URL) async throws -> ServedItem {
        guard case let .remux(audio) = plan else {
            throw SenderError.unsupportedOperation
        }
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let playlist = outputDir.appendingPathComponent("index.m3u8")
        let segmentPattern = outputDir.appendingPathComponent("seg_%03d.ts").path
        let input = source.isFileURL ? source.path : source.absoluteString
        let audioArgs = (audio == .copy) ? ["-c:a", "copy"] : ["-c:a", "aac", "-b:a", "256k"]

        // Copy video, fix audio, drop subs, segment to HLS. VOD playlist type so
        // the receiver gets a complete (ENDLIST-terminated) playlist once done.
        let args = ["-y", "-i", input, "-c:v", "copy"] + audioArgs + [
            "-sn",
            "-f", "hls",
            "-hls_time", "6",
            "-hls_playlist_type", "vod",
            "-hls_segment_filename", segmentPattern,
            playlist.path,
        ]

        let returnCode: ReturnCode? = await withCheckedContinuation { cont in
            let session = FFmpegKit.executeWithArgumentsAsync(args, withCompleteCallback: { session in
                cont.resume(returning: session?.getReturnCode())
            })
            // getSessionId() returns `long` → Swift Int (non-optional), so the
            // session-optional chain yields Int? directly.
            setSessionId(session?.getSessionId())
        }

        guard let rc = returnCode, ReturnCode.isSuccess(rc) else {
            throw SenderError.transportFailure("Remux failed (ffmpeg)")
        }
        return ServedItem(kind: .hlsPlaylist(playlist), mimeType: "application/vnd.apple.mpegurl")
    }

    func cancel() {
        lock.lock(); let id = sessionId; lock.unlock()
        if let id { FFmpegKit.cancel(id) }
    }

    private func setSessionId(_ id: Int?) {
        lock.lock(); sessionId = id; lock.unlock()
    }
}

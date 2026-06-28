import Foundation

/// Cheap container/audio remapping via ffmpeg-kit — **no video re-encode**.
/// This is what makes "any format" affordable on a phone: most incompatible
/// files are already H.264/HEVC and only need repackaging + an audio swap.
///
/// Representative ffmpeg invocations (the implementation builds these dynamically
/// from the `PlaybackPlan`):
///
///   Remux MKV(H.264 + AC3) → HLS, copy video, re-encode audio to AAC:
///     ffmpeg -i in.mkv -c:v copy -c:a aac -b:a 256k \
///            -f hls -hls_time 6 -hls_playlist_type event \
///            -hls_segment_filename seg_%03d.ts out.m3u8
///
///   Remux MKV(H.264 + AAC) → fMP4/HLS, copy everything:
///     ffmpeg -i in.mkv -c copy -f hls -hls_segment_type fmp4 out.m3u8
///
/// Subtitles: burn-in only when the target can't render the track; otherwise
/// expose as a WebVTT sidecar via the LocalMediaServer.
protocol Remuxer: AnyObject {
    /// Begins remuxing `source` per `plan` into a directory the LocalMediaServer
    /// exposes. Returns the produced playlist/file. Throws on ffmpeg failure.
    func remux(source: URL, plan: PlaybackPlan, into outputDir: URL) async throws -> ServedItem
    func cancel()
}

/// Step 4 only. Real video re-encode — flagged expensive; avoided whenever a
/// universal player is reachable (Hybrid mode routes to it instead).
protocol Transcoder: AnyObject {
    func transcode(source: URL, profile: EncodeProfile, into outputDir: URL) async throws -> ServedItem
    func cancel()
}

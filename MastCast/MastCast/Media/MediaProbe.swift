import Foundation

/// Probes a `MediaSource` into `MediaInfo` (container/codecs/bit-depth/audio) so
/// the planner can decide. Concrete impl (`FFprobeMediaProbe`) lives in Platform/
/// and uses ffmpeg-kit; this protocol keeps the core pure and testable.
protocol MediaProbe {
    func probe(_ source: MediaSource) async throws -> MediaInfo
}

enum ProbeError: Error {
    case unreadable
    case noVideoStream
    case timedOut
}

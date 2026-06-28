import Foundation

struct CastMetadata {
    var title: String
    var subtitle: String?
    var artworkURL: URL?
    var mimeType: String      // e.g. "application/x-mpegURL" for HLS, "video/mp4"
}

/// One conformer per transport (Cast, AirPlay, DLNA, Roku, TVPlayer).
/// The planner decides *what* URL to load; the sender knows *how* for its protocol.
protocol MediaSender: AnyObject {
    var transport: Transport { get }

    func connect(to receiver: Receiver) async throws
    func load(url: URL, metadata: CastMetadata) async throws
    func play() async throws
    func pause() async throws
    func seek(to seconds: Double) async throws
    func stop() async throws
    func disconnect()
}

enum SenderError: Error {
    case notConnected
    case unsupportedOperation
    case transportFailure(String)
}

import Foundation

/// Embedded HTTP server that exposes remuxed or local media to the receiver over
/// the LAN as HLS (preferred) or a progressive MP4.
///
/// Implementation note: back this with GCDWebServer (recommended) or Swifter.
/// - Bind to 0.0.0.0 on an ephemeral port.
/// - Advertise the phone's current Wi-Fi IP (en0) in the URL handed to the receiver.
/// - For remux/transcode, serve the HLS playlist + segments produced by `Remuxer`.
/// - Support HTTP range requests for seeking on progressive MP4.
/// - Tear down on stop() to free the port and stop background networking.
protocol LocalMediaServer: AnyObject {
    /// Starts the server and returns the base URL reachable by receivers on the LAN.
    func start() throws -> URL
    /// Publishes a media item; returns the URL the receiver should load.
    func serve(item: ServedItem) -> URL
    func stop()
}

struct ServedItem {
    enum Kind { case hlsPlaylist(URL), progressiveFile(URL) }
    let kind: Kind
    let mimeType: String   // "application/x-mpegURL" or "video/mp4"
}

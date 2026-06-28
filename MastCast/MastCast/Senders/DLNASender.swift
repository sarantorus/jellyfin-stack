import Foundation

/// DLNA/UPnP AVTransport sender (older / budget smart TVs).
///
/// Implementation note: plain SOAP over HTTP to the renderer's control URL
/// (discovered from its device description XML).
/// - `SetAVTransportURI` with the served URL + a DIDL-Lite metadata blob.
/// - `Play` (Speed=1). Controls: `Pause`, `Seek` (REL_TIME), `Stop`.
/// - Poll `GetPositionInfo` for progress; many renderers are quirky, so be lenient.
final class DLNASender: MediaSender {
    let transport: Transport = .dlna

    func connect(to receiver: Receiver) async throws { /* TODO: fetch device description, find AVTransport control URL */ }
    func load(url: URL, metadata: CastMetadata) async throws { /* TODO: SOAP SetAVTransportURI */ }
    func play() async throws { /* TODO: SOAP Play */ }
    func pause() async throws { /* TODO: SOAP Pause */ }
    func seek(to seconds: Double) async throws { /* TODO: SOAP Seek REL_TIME */ }
    func stop() async throws { /* TODO: SOAP Stop */ }
    func disconnect() { /* TODO */ }
}

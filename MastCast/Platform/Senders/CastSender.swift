import Foundation
import GoogleCast   // google-cast-sdk. See SETUP.md.

/// Google Cast sender (Chromecast / Android TV / Google TV), implemented against
/// the Cast SDK's session + remote media client.
final class CastSender: NSObject, MediaSender, GCKSessionManagerListener {
    let transport: Transport = .googleCast

    private var sessionManager: GCKSessionManager { GCKCastContext.sharedInstance().sessionManager }
    private var remoteMediaClient: GCKRemoteMediaClient? { sessionManager.currentCastSession?.remoteMediaClient }
    private var connectContinuation: CheckedContinuation<Void, Error>?

    /// Resolve a `Receiver` back to the live `GCKDevice` the SDK is tracking.
    private func device(for receiver: Receiver) -> GCKDevice? {
        let dm = GCKCastContext.sharedInstance().discoveryManager
        for i in 0..<dm.deviceCount where dm.device(at: i).deviceID == receiver.id {
            return dm.device(at: i)
        }
        return nil
    }

    func connect(to receiver: Receiver) async throws {
        guard let device = device(for: receiver) else {
            throw SenderError.transportFailure("Cast device \(receiver.name) no longer available")
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connectContinuation = cont
            sessionManager.add(self)
            if !sessionManager.startSession(with: device) {
                connectContinuation = nil
                sessionManager.remove(self)
                cont.resume(throwing: SenderError.transportFailure("Could not start Cast session"))
            }
        }
    }

    func load(url: URL, metadata: CastMetadata) async throws {
        guard let client = remoteMediaClient else { throw SenderError.notConnected }

        let mediaMetadata = GCKMediaMetadata(metadataType: .movie)
        mediaMetadata.setString(metadata.title, forKey: kGCKMetadataKeyTitle)
        if let subtitle = metadata.subtitle { mediaMetadata.setString(subtitle, forKey: kGCKMetadataKeySubtitle) }
        if let art = metadata.artworkURL { mediaMetadata.addImage(GCKImage(url: art, width: 480, height: 720)) }

        let builder = GCKMediaInformationBuilder(contentURL: url)
        builder.streamType = .buffered
        builder.contentType = metadata.mimeType
        builder.metadata = mediaMetadata
        let mediaInfo = builder.build()

        try await request { client.loadMedia(mediaInfo) }
    }

    func play()  async throws { try await request { remoteMediaClient?.play() } }
    func pause() async throws { try await request { remoteMediaClient?.pause() } }
    func stop()  async throws { try await request { remoteMediaClient?.stop() } }

    func seek(to seconds: Double) async throws {
        let options = GCKMediaSeekOptions()
        options.interval = seconds
        try await request { remoteMediaClient?.seek(with: options) }
    }

    func disconnect() {
        sessionManager.endSession()
        sessionManager.remove(self)
    }

    // MARK: - GCKRequest bridging

    /// Wrap a `GCKRequest`-returning call as async, completing on delegate callback.
    private func request(_ make: () -> GCKRequest?) async throws {
        guard let req = make() else { throw SenderError.notConnected }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            req.delegate = RequestDelegate(cont)
        }
    }

    // MARK: - GCKSessionManagerListener

    func sessionManager(_ sm: GCKSessionManager, didStart session: GCKSession) {
        connectContinuation?.resume(); connectContinuation = nil
    }
    func sessionManager(_ sm: GCKSessionManager, didFailToStart session: GCKSession, withError error: Error) {
        connectContinuation?.resume(throwing: error); connectContinuation = nil
    }
}

/// Bridges a single `GCKRequest` completion to a continuation. Retained by the
/// request via its `delegate` until the callback fires.
private final class RequestDelegate: NSObject, GCKRequestDelegate {
    private var cont: CheckedContinuation<Void, Error>?
    init(_ cont: CheckedContinuation<Void, Error>) { self.cont = cont }
    func requestDidComplete(_ request: GCKRequest) { cont?.resume(); cont = nil }
    func request(_ request: GCKRequest, didFailWithError error: GCKError) {
        cont?.resume(throwing: error); cont = nil
    }
}

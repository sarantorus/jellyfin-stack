import Foundation
import GoogleCast   // google-cast-sdk. See SETUP.md.

/// Google Cast sender (Chromecast / Android TV / Google TV), implemented against
/// the Cast SDK's session + remote media client.
///
/// `@MainActor`-isolated because the Cast SDK requires main-thread access and its
/// listener/delegate callbacks are delivered on the main thread; this also makes
/// the continuation bookkeeping race-free.
@MainActor
final class CastSender: NSObject, MediaSender, GCKSessionManagerListener {
    nonisolated let transport: Transport = .googleCast

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
        guard connectContinuation == nil else {
            throw SenderError.transportFailure("A Cast connection is already in progress")
        }
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

        let options = GCKMediaLoadOptions()
        options.autoplay = true
        try await request { client.loadMedia(mediaInfo, with: options) }
    }

    func play()  async throws { try await request { remoteMediaClient?.play() } }
    func pause() async throws { try await request { remoteMediaClient?.pause() } }
    func stop()  async throws { try await request { remoteMediaClient?.stop() } }

    func seek(to seconds: Double) async throws {
        let options = GCKMediaSeekOptions()
        options.interval = seconds
        try await request { remoteMediaClient?.seek(with: options) }
    }

    nonisolated func disconnect() {
        Task { @MainActor in
            sessionManager.endSession()
            sessionManager.remove(self)
        }
    }

    // MARK: - GCKRequest bridging

    /// Wrap a `GCKRequest`-returning call as async, completing on the delegate
    /// callback. `GCKRequest.delegate` is **weak**, so the delegate must retain
    /// itself until a terminal callback fires (complete / fail / cancel / abort).
    private func request(_ make: () -> GCKRequest?) async throws {
        guard let req = make() else { throw SenderError.notConnected }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            req.delegate = RequestDelegate(cont)   // RequestDelegate keeps itself alive
        }
    }

    // MARK: - GCKSessionManagerListener (delivered on main thread)

    nonisolated func sessionManager(_ sm: GCKSessionManager, didStart session: GCKSession) {
        Task { @MainActor in resumeConnect(with: nil) }
    }
    nonisolated func sessionManager(_ sm: GCKSessionManager, didFailToStart session: GCKSession, withError error: Error) {
        Task { @MainActor in resumeConnect(with: error) }
    }
    nonisolated func sessionManager(_ sm: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        // A session can end before `didStart` ever fires; don't leave connect hanging.
        Task { @MainActor in resumeConnect(with: error ?? SenderError.transportFailure("Cast session ended")) }
    }

    private func resumeConnect(with error: Error?) {
        guard let cont = connectContinuation else { return }
        connectContinuation = nil
        if let error { cont.resume(throwing: error) } else { cont.resume() }
    }
}

/// Bridges a single `GCKRequest` completion to a continuation. Retains itself via
/// `selfRetain` until a terminal callback fires, because `GCKRequest.delegate` is
/// a weak reference and would otherwise deallocate it immediately (→ a hang).
private final class RequestDelegate: NSObject, GCKRequestDelegate {
    private var cont: CheckedContinuation<Void, Error>?
    private var selfRetain: RequestDelegate?

    init(_ cont: CheckedContinuation<Void, Error>) {
        self.cont = cont
        super.init()
        self.selfRetain = self
    }

    private func finish(_ error: Error?) {
        guard let cont else { return }
        self.cont = nil
        if let error { cont.resume(throwing: error) } else { cont.resume() }
        selfRetain = nil
    }

    func requestDidComplete(_ request: GCKRequest) { finish(nil) }
    func request(_ request: GCKRequest, didFailWithError error: GCKError) { finish(error) }
    func requestDidCancel(_ request: GCKRequest) {
        finish(SenderError.transportFailure("Cast request was cancelled"))
    }
    func request(_ request: GCKRequest, didAbortWith abortReason: GCKRequestAbortReason) {
        finish(SenderError.transportFailure("Cast request aborted (\(abortReason.rawValue))"))
    }
}

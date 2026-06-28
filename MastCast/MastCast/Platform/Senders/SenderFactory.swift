import Foundation

/// Maps a discovered `Receiver` to the right `MediaSender` for its transport.
/// `@MainActor` because some senders (Cast, AirPlay) are main-actor isolated.
@MainActor
enum SenderFactory {
    static func make(for receiver: Receiver) -> MediaSender {
        switch receiver.transport {
        case .googleCast: return CastSender()
        case .airplay:    return AirPlaySender()
        case .dlna:       return DLNASender()
        case .roku:       return RokuSender()
        case .tvPlayer:   return TVPlayerSender()
        }
    }
}

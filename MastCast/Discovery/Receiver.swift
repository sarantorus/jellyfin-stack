import Foundation

enum Transport: String, Equatable {
    case airplay
    case googleCast
    case dlna
    case roku
    case tvPlayer   // Kodi / VLC / Infuse / Jellyfin
}

/// A discovered casting target on the local network.
struct Receiver: Identifiable, Equatable {
    let id: String          // stable per device (e.g. Cast deviceID, mDNS name)
    let name: String        // user-facing ("Living Room TV")
    let host: String        // resolved IP/hostname
    let transport: Transport
    var capabilities: Capabilities
    /// Transport-specific endpoint: DLNA device-description URL (SSDP LOCATION),
    /// Roku ECP base (http://host:8060). Nil for transports that only need `host`.
    var serviceURL: String? = nil

    var isUniversalPlayer: Bool { capabilities.isUniversalPlayer }
}

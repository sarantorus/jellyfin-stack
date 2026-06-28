import Foundation

/// Aggregates receivers from every transport into a single observable list.
///
/// Implementation note:
/// - Google Cast / Android TV → Bonjour `_googlecast._tcp` (NWBrowser), or the
///   Cast SDK's own `GCKDiscoveryManager`.
/// - AirPlay → Bonjour `_airplay._tcp` and `_raop._tcp`.
/// - Universal players → Kodi advertises `_xbmc-jsonrpc._tcp`; Jellyfin via its
///   discovery broadcast; VLC over `_airplay`/HTTP. Mark these `isUniversalPlayer`.
/// - DLNA → SSDP M-SEARCH over UDP multicast 239.255.255.250:1900
///   (ST: urn:schemas-upnp-org:device:MediaRenderer:1).
/// - Roku → SSDP (ST: roku:ecp), then ECP HTTP on :8060.
///
/// Each transport resolves into a `Receiver` with a starting `Capabilities`
/// profile, refined per-device where the protocol exposes details (Cast model,
/// DLNA DIDL protocolInfo, etc.).
protocol DiscoveryManager: AnyObject {
    /// Current set of receivers; updates as devices appear/disappear.
    var receivers: [Receiver] { get }
    func startDiscovery()
    func stopDiscovery()
    /// Callback fired whenever `receivers` changes.
    var onChange: (([Receiver]) -> Void)? { get set }
}

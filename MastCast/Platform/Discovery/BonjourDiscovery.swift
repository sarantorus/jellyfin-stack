import Foundation

/// Discovers Bonjour/mDNS receivers (AirPlay and Kodi) using `NetService`, which
/// resolves directly to IP addresses. Each browsed service type maps to a
/// transport + capability profile.
///
/// Requires the service types in `NSBonjourServices` + Local Network permission.
final class BonjourDiscovery: NSObject, DiscoveryManager {

    private struct ServiceSpec {
        let type: String
        let transport: Transport
        let capabilities: Capabilities
    }

    private let specs: [ServiceSpec] = [
        .init(type: "_airplay._tcp.",        transport: .airplay,  capabilities: .airplay),
        .init(type: "_xbmc-jsonrpc-h._tcp.", transport: .tvPlayer, capabilities: .universalPlayer),
    ]

    private(set) var receivers: [Receiver] = []
    var onChange: (([Receiver]) -> Void)?

    private var browsers: [NetServiceBrowser] = []
    private var resolving: Set<NetService> = []
    private var found: [String: Receiver] = [:]   // keyed by Receiver.id

    func startDiscovery() {
        for spec in specs {
            let browser = NetServiceBrowser()
            browser.delegate = self
            browser.searchForServices(ofType: spec.type, inDomain: "local.")
            browsers.append(browser)
        }
    }

    func stopDiscovery() {
        browsers.forEach { $0.stop() }
        browsers.removeAll()
        resolving.removeAll()
    }

    private func spec(for service: NetService) -> ServiceSpec? {
        specs.first { $0.type == service.type }
    }
}

extension BonjourDiscovery: NetServiceBrowserDelegate, NetServiceDelegate {

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        resolving.insert(service)                 // retain during resolution
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        let id = "\(service.type)\(service.name)"
        found[id] = nil
        emit()
    }

    func netServiceDidResolveAddress(_ service: NetService) {
        defer { resolving.remove(service) }
        guard let spec = spec(for: service), let ip = Self.ipv4(from: service) else { return }
        let id = "\(service.type)\(service.name)"
        found[id] = Receiver(
            id: id,
            name: service.name,
            host: ip,
            transport: spec.transport,
            capabilities: spec.capabilities)
        emit()
    }

    func netService(_ service: NetService, didNotResolve errorDict: [String: NSNumber]) {
        resolving.remove(service)
    }

    private func emit() {
        receivers = Array(found.values)
        onChange?(receivers)
    }

    /// Extract the first IPv4 address from a resolved service's `addresses`.
    private static func ipv4(from service: NetService) -> String? {
        guard let addresses = service.addresses else { return nil }
        for data in addresses {
            let ip: String? = data.withUnsafeBytes { raw -> String? in
                guard let base = raw.baseAddress else { return nil }
                let sa = base.assumingMemoryBound(to: sockaddr.self)
                guard sa.pointee.sa_family == UInt8(AF_INET) else { return nil }
                var addr = base.assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN))
                return String(cString: buffer)
            }
            if let ip { return ip }
        }
        return nil
    }
}

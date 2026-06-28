import Foundation
import Network

/// Discovers DLNA MediaRenderers and Roku devices via SSDP (UDP multicast
/// M-SEARCH to 239.255.255.250:1900) and parses the responses.
///
/// NOTE: sending to a multicast group on iOS 14+ requires the **multicast
/// entitlement** (`com.apple.developer.networking.multicast`), which Apple grants
/// on request. See SETUP.md. Without it, this transport silently finds nothing.
final class SSDPDiscovery: DiscoveryManager {

    private(set) var receivers: [Receiver] = []
    var onChange: (([Receiver]) -> Void)?

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "mastcast.ssdp")
    private var found: [String: Receiver] = [:]

    private let searchTargets = [
        "urn:schemas-upnp-org:device:MediaRenderer:1",
        "roku:ecp",
    ]

    func startDiscovery() {
        guard let port = NWEndpoint.Port(rawValue: 1900) else { return }
        let conn = NWConnection(host: "239.255.255.250", port: port, using: .udp)
        connection = conn
        conn.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                self?.sendSearches()
                self?.receiveNext()
            }
        }
        conn.start(queue: queue)
    }

    func stopDiscovery() {
        connection?.cancel()
        connection = nil
    }

    // MARK: - SSDP

    private func sendSearches() {
        for st in searchTargets {
            let msg = """
            M-SEARCH * HTTP/1.1\r
            HOST: 239.255.255.250:1900\r
            MAN: "ssdp:discover"\r
            MX: 2\r
            ST: \(st)\r
            \r

            """
            connection?.send(content: msg.data(using: .utf8), completion: .idempotent)
        }
    }

    private func receiveNext() {
        connection?.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data, let text = String(data: data, encoding: .utf8) {
                self.handle(response: text)
            }
            if error == nil { self.receiveNext() }   // keep listening
        }
    }

    private func handle(response: String) {
        let headers = Self.parseHeaders(response)
        guard let location = headers["location"], let locURL = URL(string: location), let host = locURL.host else { return }
        let blob = (headers["server"] ?? "") + (headers["st"] ?? "") + (headers["usn"] ?? "")
        let isRoku = blob.lowercased().contains("roku")

        let receiver: Receiver
        if isRoku {
            receiver = Receiver(
                id: "roku:\(host)", name: "Roku (\(host))", host: host,
                transport: .roku, capabilities: .roku,
                serviceURL: "http://\(host):8060")
        } else {
            receiver = Receiver(
                id: "dlna:\(location)", name: "DLNA (\(host))", host: host,
                transport: .dlna, capabilities: .dlnaGeneric,
                serviceURL: location)
        }
        if found[receiver.id] == nil {
            found[receiver.id] = receiver
            receivers = Array(found.values)
            onChange?(receivers)
        }
    }

    /// Parse the HTTP-style SSDP response into lowercase-keyed headers.
    static func parseHeaders(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(whereSeparator: { $0 == "\r" || $0 == "\n" }) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if !key.isEmpty { result[key] = value }
        }
        return result
    }
}

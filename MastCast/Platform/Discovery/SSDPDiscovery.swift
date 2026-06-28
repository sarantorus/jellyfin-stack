import Foundation
import Network

/// Discovers DLNA MediaRenderers and Roku devices via SSDP (UDP multicast
/// M-SEARCH to 239.255.255.250:1900) and parses the responses.
///
/// Uses `NWConnectionGroup` + `NWMulticastGroup`: a plain `NWConnection` to the
/// group address can transmit but won't deliver the unicast replies devices send
/// back to our source port, so the group API is required.
///
/// NOTE: multicast on iOS 14+ requires the **multicast entitlement**
/// (`com.apple.developer.networking.multicast`), granted by Apple on request.
/// See SETUP.md. Without it the group send is silently dropped → nothing found.
final class SSDPDiscovery: DiscoveryManager {

    private(set) var receivers: [Receiver] = []
    var onChange: (([Receiver]) -> Void)?

    private var group: NWConnectionGroup?
    private let queue = DispatchQueue(label: "mastcast.ssdp")
    private var found: [String: Receiver] = [:]   // queue-confined

    private let searchTargets = [
        "urn:schemas-upnp-org:device:MediaRenderer:1",
        "roku:ecp",
    ]

    func startDiscovery() {
        guard let port = NWEndpoint.Port(rawValue: 1900) else { return }
        do {
            let multicast = try NWMulticastGroup(for: [.hostPort(host: "239.255.255.250", port: port)])
            let group = NWConnectionGroup(with: multicast, using: .udp)
            self.group = group
            group.setReceiveHandler(maximumMessageSize: 65535, rejectOversizedMessages: true) { [weak self] _, content, _ in
                if let content, let text = String(data: content, encoding: .utf8) {
                    self?.handle(response: text)
                }
            }
            group.stateUpdateHandler = { [weak self] state in
                if case .ready = state { self?.sendSearches() }
            }
            group.start(queue: queue)
        } catch {
            // Invalid group or missing multicast entitlement — discovery yields nothing.
        }
    }

    func stopDiscovery() {
        group?.cancel()
        group = nil
    }

    // MARK: - SSDP

    private func sendSearches() {
        for st in searchTargets {
            // Exact CRLF framing terminated by a single blank line.
            let msg = "M-SEARCH * HTTP/1.1\r\n"
                + "HOST: 239.255.255.250:1900\r\n"
                + "MAN: \"ssdp:discover\"\r\n"
                + "MX: 2\r\n"
                + "ST: \(st)\r\n\r\n"
            group?.send(content: msg.data(using: .utf8), completion: { _ in })
        }
    }

    private func handle(response: String) {
        let headers = Self.parseHeaders(response)
        guard let location = headers["location"], let locURL = URL(string: location), let host = locURL.host else { return }
        let blob = ((headers["server"] ?? "") + (headers["st"] ?? "") + (headers["usn"] ?? "")).lowercased()
        let isRoku = blob.contains("roku")

        let receiver: Receiver
        if isRoku {
            receiver = Receiver(
                id: "roku:\(host)", name: "Roku (\(host))", host: host,
                transport: .roku, capabilities: .roku,
                serviceURL: "http://\(host):8060")
        } else {
            receiver = Receiver(
                id: "dlna:\(host)", name: "DLNA (\(host))", host: host,
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

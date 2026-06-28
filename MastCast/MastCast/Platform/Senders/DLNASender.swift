import Foundation

/// DLNA/UPnP AVTransport sender (older / budget smart TVs).
///
/// Resolves the AVTransport control URL from the device-description XML
/// (`receiver.serviceURL`, the SSDP LOCATION), then drives playback with SOAP
/// (`SetAVTransportURI` + `Play`/`Pause`/`Stop`/`Seek`).
final class DLNASender: MediaSender {
    let transport: Transport = .dlna

    private let serviceType = "urn:schemas-upnp-org:service:AVTransport:1"
    private var controlURL: URL?
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func connect(to receiver: Receiver) async throws {
        guard let loc = receiver.serviceURL, let descURL = URL(string: loc) else {
            throw SenderError.transportFailure("DLNA device has no description URL")
        }
        let (data, _) = try await session.data(from: descURL)
        guard let control = Self.avTransportControlURL(descriptionXML: data, base: descURL) else {
            throw SenderError.transportFailure("No AVTransport service on device")
        }
        controlURL = control
    }

    func load(url: URL, metadata: CastMetadata) async throws {
        let didl = Self.didlMetadata(url: url, title: metadata.title, mime: metadata.mimeType)
        try await soap(action: "SetAVTransportURI", arguments: [
            ("InstanceID", "0"),
            ("CurrentURI", Self.xmlEscape(url.absoluteString)),
            ("CurrentURIMetaData", Self.xmlEscape(didl)),
        ])
        try await play()
    }

    func play() async throws {
        try await soap(action: "Play", arguments: [("InstanceID", "0"), ("Speed", "1")])
    }

    func pause() async throws {
        try await soap(action: "Pause", arguments: [("InstanceID", "0")])
    }

    func stop() async throws {
        try await soap(action: "Stop", arguments: [("InstanceID", "0")])
    }

    func seek(to seconds: Double) async throws {
        let s = Int(seconds)
        let target = String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        try await soap(action: "Seek", arguments: [("InstanceID", "0"), ("Unit", "REL_TIME"), ("Target", target)])
    }

    func disconnect() { controlURL = nil }

    // MARK: - SOAP

    private func soap(action: String, arguments: [(String, String)]) async throws {
        guard let controlURL else { throw SenderError.notConnected }
        let argsXML = arguments.map { "<\($0.0)>\($0.1)</\($0.0)>" }.joined()
        let envelope = """
        <?xml version="1.0" encoding="utf-8"?>\
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" \
        s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\
        <s:Body><u:\(action) xmlns:u="\(serviceType)">\(argsXML)</u:\(action)></s:Body></s:Envelope>
        """
        var request = URLRequest(url: controlURL)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"\(serviceType)#\(action)\"", forHTTPHeaderField: "SOAPAction")
        request.httpBody = envelope.data(using: .utf8)

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SenderError.transportFailure("DLNA SOAP \(action) failed")
        }
    }

    // MARK: - Description parsing

    /// Find the AVTransport service's controlURL, resolved against the base URL.
    static func avTransportControlURL(descriptionXML: Data, base: URL) -> URL? {
        let parser = DLNADescriptionParser(wantedServiceType: "AVTransport")
        guard let control = parser.parse(descriptionXML) else { return nil }
        // controlURL may be absolute or relative to the description URL's origin.
        if let abs = URL(string: control), abs.scheme != nil { return abs }
        return URL(string: control, relativeTo: base)?.absoluteURL
    }

    static func didlMetadata(url: URL, title: String, mime: String) -> String {
        """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" \
        xmlns:dc="http://purl.org/dc/elements/1.1/" \
        xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">\
        <item id="0" parentID="-1" restricted="1"><dc:title>\(xmlEscape(title))</dc:title>\
        <upnp:class>object.item.videoItem</upnp:class>\
        <res protocolInfo="http-get:*:\(mime):*">\(xmlEscape(url.absoluteString))</res></item></DIDL-Lite>
        """
    }

    static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

/// Minimal XML scan for the `<service>` whose `<serviceType>` contains the wanted
/// token, returning its `<controlURL>`.
private final class DLNADescriptionParser: NSObject, XMLParserDelegate {
    private let wantedServiceType: String
    private var currentElement = ""
    private var inService = false
    private var serviceType = ""
    private var controlURL = ""
    private var matchedControlURL: String?

    init(wantedServiceType: String) { self.wantedServiceType = wantedServiceType }

    func parse(_ data: Data) -> String? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return matchedControlURL
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String]) {
        currentElement = elementName
        if elementName == "service" { inService = true; serviceType = ""; controlURL = "" }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inService else { return }
        switch currentElement {
        case "serviceType": serviceType += string
        case "controlURL": controlURL += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "service" {
            if serviceType.contains(wantedServiceType), matchedControlURL == nil {
                matchedControlURL = controlURL.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            inService = false
        }
        currentElement = ""
    }
}

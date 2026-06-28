import Foundation
import GoogleCast   // google-cast-sdk. See SETUP.md.

/// Discovers Google Cast receivers (Chromecast / Android TV / Google TV) via the
/// Cast SDK and maps them to `Receiver`s. This is the first transport wired
/// end-to-end; AirPlay/DLNA/Roku discovery plug into the same `onChange` contract.
final class CastDiscovery: NSObject, DiscoveryManager, GCKDiscoveryManagerListener {

    private(set) var receivers: [Receiver] = []
    var onChange: (([Receiver]) -> Void)?

    private var discoveryManager: GCKDiscoveryManager {
        GCKCastContext.sharedInstance().discoveryManager
    }

    /// Call once at launch before using discovery/sessions.
    static func configureCastContext() {
        let criteria = GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        options.physicalVolumeButtonsWillControlDeviceVolume = true
        GCKCastContext.setSharedInstanceWith(options)
    }

    func startDiscovery() {
        discoveryManager.add(self)
        discoveryManager.startDiscovery()
        rebuild()
    }

    func stopDiscovery() {
        discoveryManager.stopDiscovery()
        discoveryManager.remove(self)
    }

    // MARK: - GCKDiscoveryManagerListener

    func didUpdateDeviceList() { rebuild() }
    func didInsert(_ device: GCKDevice, at index: UInt) { rebuild() }
    func didUpdate(_ device: GCKDevice, at index: UInt) { rebuild() }
    func didRemove(_ device: GCKDevice, at index: UInt) { rebuild() }

    // MARK: - Mapping

    private func rebuild() {
        let count = discoveryManager.deviceCount
        var result: [Receiver] = []
        for i in 0..<count {
            let device = discoveryManager.device(at: i)
            result.append(Receiver(
                id: device.deviceID,
                name: device.friendlyName ?? device.deviceID,
                host: device.ipAddress ?? "",
                transport: .googleCast,
                capabilities: Self.capabilities(for: device)))
        }
        receivers = result
        onChange?(result)
    }

    /// Refine the capability profile from the device model where possible.
    /// 4K-class Cast devices add HEVC / 10-bit / AC3; baseline ones don't.
    private static func capabilities(for device: GCKDevice) -> Capabilities {
        let model = (device.modelName ?? "").lowercased()
        let is4K = model.contains("ultra") || model.contains("google tv") || model.contains("4k")
        return is4K ? .chromecast4K : .chromecastBaseline
    }
}

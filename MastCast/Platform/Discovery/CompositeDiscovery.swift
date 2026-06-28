import Foundation

/// Aggregates several `DiscoveryManager`s (Cast + Bonjour + SSDP) into one merged,
/// de-duplicated receiver list. Sub-managers fire `onChange` from different
/// queues, so updates are serialized with a lock.
final class CompositeDiscovery: DiscoveryManager {

    private(set) var receivers: [Receiver] = []
    var onChange: (([Receiver]) -> Void)?

    private let managers: [DiscoveryManager]
    private let lock = NSLock()
    private var byManager: [Int: [Receiver]] = [:]

    init(managers: [DiscoveryManager]? = nil) {
        self.managers = managers ?? [CastDiscovery(), BonjourDiscovery(), SSDPDiscovery()]
        for (index, manager) in self.managers.enumerated() {
            manager.onChange = { [weak self] recs in self?.update(index: index, receivers: recs) }
        }
    }

    func startDiscovery() { managers.forEach { $0.startDiscovery() } }
    func stopDiscovery() { managers.forEach { $0.stopDiscovery() } }

    private func update(index: Int, receivers: [Receiver]) {
        lock.lock()
        byManager[index] = receivers
        let merged = mergeLocked()
        self.receivers = merged
        lock.unlock()
        onChange?(merged)
    }

    /// Must be called with `lock` held. Last-writer-wins per receiver id.
    private func mergeLocked() -> [Receiver] {
        var seen: [String: Receiver] = [:]
        for recs in byManager.values {
            for r in recs { seen[r.id] = r }
        }
        return seen.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

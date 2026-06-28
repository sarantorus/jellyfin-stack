# Integrating MastCast as a reusable casting module

Goal: add MastCast to your existing iPhone app as a **"cast to TV" feature** —
your app stays the shell; MastCast provides discovery + play-to-TV. The whole
public surface is one facade (`CastController`); everything else stays internal.

Run this on your Mac (desktop Claude Code can execute it — say *"execute
INTEGRATION.md"*). Steps are ordered; each is compiler-checkable.

---

## 1. Turn MastCast into a Swift package with two products

MastCast already separates a cross-platform core from the Apple/SDK layer. Expose
both as library products so your app depends on the module:

- **`MastCastCore`** — engine, models, protocols. Pure Foundation, unit-tested.
- **`MastCast`** — the iOS module: senders, discovery, coordinator, and the
  public `CastController` facade. Depends on Core + GoogleCast + GCDWebServer.

Replace `Package.swift` with:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MastCast",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "MastCastCore", targets: ["MastCastCore"]),
        .library(name: "MastCast", targets: ["MastCast"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SRGSSR/google-cast-sdk", from: "4.8.4"),
        .package(url: "https://github.com/yene/GCDWebServer", from: "3.5.7"),
    ],
    targets: [
        .target(
            name: "MastCastCore",
            path: "MastCast",
            exclude: ["Platform"]),
        .target(
            name: "MastCast",
            dependencies: [
                "MastCastCore",
                .product(name: "GoogleCast", package: "google-cast-sdk"),
                .product(name: "GCDWebServer", package: "GCDWebServer"),
            ],
            path: "MastCast/Platform"),
        .testTarget(
            name: "MastCastCoreTests",
            dependencies: ["MastCastCore"],
            path: "Tests"),
    ]
)
```

Notes:
- The package is now Apple-only (the GoogleCast binary can't resolve on Linux),
  so run tests on macOS: `swift test`. That's fine — you have a Mac.
- ffmpeg-kit stays optional via `#if canImport(ffmpegkit)`. To enable on-phone
  remux, add the xcframework target to the `MastCast` target later.
- The `Platform/App/` SwiftUI demo app can stay (it's just example code) or be
  deleted from the `MastCast` target sources — your app provides the real UI.

## 2. Add the public facade (the ONLY thing your app touches)

Create `MastCast/Platform/CastController.swift`. It wraps the internal
`CastCoordinator` and exposes a tiny, decoupled API so the rest stays internal:

```swift
import SwiftUI

/// A discovered TV, decoupled from internal types.
public struct CastReceiver: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let kind: String   // "googleCast" | "airplay" | "dlna" | "roku" | "tvPlayer"
}

public enum CastState: Equatable {
    case idle, discovering, probing, connecting, playing, failed(String)
}

/// Public entry point for the casting module.
@MainActor
public final class CastController: ObservableObject {
    @Published public private(set) var receivers: [CastReceiver] = []
    @Published public private(set) var state: CastState = .idle

    private let coordinator = CastCoordinator()
    private var internalReceivers: [Receiver] = []

    public init() {
        coordinator.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.sync() }
            .store(in: &cancellables)
    }
    private var cancellables = Set<AnyCancellable>()

    public func startDiscovery() { coordinator.startDiscovery() }
    public func stopDiscovery() { coordinator.stopDiscovery() }

    /// Cast a stream URL or local file path to the chosen receiver.
    public func cast(_ urlString: String, to receiverID: String, title: String) async {
        guard let target = internalReceivers.first(where: { $0.id == receiverID }) else { return }
        await coordinator.cast(urlString, to: target, title: title)
    }
    public func stop() async { await coordinator.stop() }

    private func sync() {
        internalReceivers = coordinator.receivers
        receivers = internalReceivers.map {
            CastReceiver(id: $0.id, name: $0.name, kind: $0.transport.rawValue)
        }
        state = Self.map(coordinator.status)
    }
    private static func map(_ s: CastCoordinator.Status) -> CastState {
        switch s {
        case .idle: return .idle
        case .discovering: return .discovering
        case .probing: return .probing
        case .casting: return .connecting
        case .playing: return .playing
        case .failed(let m): return .failed(m)
        }
    }
}
```

> `objectWillChange` is the simplest bridge; if you prefer, expose an `onChange`
> on `CastCoordinator` instead and skip Combine. Either compiles.

## 3. Make only the facade surface public

You do NOT need to make 20 files public — only what `CastController` exposes.
That's `CastController`, `CastReceiver`, `CastState` (above) — already `public`.
The internal `Receiver`, `Transport`, `CastCoordinator` stay `internal` because
the app never sees them. If the compiler complains a referenced symbol needs to
be public, it'll name it — make exactly those public, nothing more.

## 4. Add the package to your app

In your app's Xcode project: **File → Add Package Dependencies → Add Local…**
and select the `MastCast` folder. Add the **`MastCast`** library product to your
app target. Then add the two SPM deps when prompted (they resolve automatically).

## 5. Copy the required keys into YOUR app's Info.plist / entitlements

From this repo's `Info.plist`: `NSLocalNetworkUsageDescription`,
`NSBonjourServices` (all listed types), `NSAppTransportSecurity`
(`NSAllowsLocalNetworking`), `UIBackgroundModes` (audio). For DLNA/Roku, add the
multicast entitlement (see `MastCast.entitlements` / SETUP.md).

In your app launch (e.g. `App.init`), call `CastDiscovery.configureCastContext()`
once — make that method `public` (it's the one extra public symbol you need).

## 6. Wire a Cast button in your UI

```swift
struct CastSheet: View {
    @StateObject var cast = CastController()
    let url: String
    var body: some View {
        List(cast.receivers) { r in
            Button(r.name) { Task { await cast.cast(url, to: r.id, title: "Now Playing") } }
        }
        .onAppear { cast.startDiscovery() }
        .onDisappear { cast.stopDiscovery() }
        .overlay(alignment: .bottom) { Text(String(describing: cast.state)) }
    }
}
```

## 6a. If your app ALREADY casts to Kodi (e.g. the "4789" app)

Your existing Kodi casting maps directly onto MastCast's `TVPlayerSender` /
`.routeToPlayer` path — so MastCast is additive, not a rewrite. Two ways to fold
it in:

- **Recommended — make MastCast the casting backend.** Replace your Kodi-only
  call sites with `CastController`. Your Kodi boxes still appear (MastCast
  discovers them via Bonjour `_xbmc-jsonrpc-h._tcp` and drives them with the same
  JSON-RPC `Player.Open` you already use), and you *also* get Chromecast/AirPlay/
  DLNA/Roku for free. The engine routes hard codecs to Kodi automatically — the
  thing you were doing manually becomes the fallback tier.
- **Minimal — keep your Kodi UI, add the rest.** Leave your current Kodi flow
  untouched; show MastCast's `receivers` filtered to `kind != "tvPlayer"` as
  "other TVs." Lower risk, but you maintain two casting code paths.

If 4789 configures Kodi by **manual IP/port** (not discovery), you can feed that
straight into MastCast: construct a `Receiver(transport: .tvPlayer,
host: "<ip>", capabilities: .universalPlayer, ...)` and call the coordinator —
or add a small `cast(_:toManualKodi:)` helper on `CastController`. (Make
`Receiver` / `Capabilities` / `Transport` public only if you go this route.)

Porting checklist for desktop Claude Code (it can read both repos):
1. Find 4789's current Kodi cast call site(s) and how it gets the Kodi host.
2. Add the MastCast package (steps 1–5) to 4789.
3. Swap the Kodi call for `CastController.cast(url:to:title:)`, or keep Kodi and
   add MastCast for non-Kodi devices.
4. Confirm 4789's existing Kodi target still works through MastCast, then verify
   a Chromecast/AirPlay cast.

## 7. Build & verify

`swift test` (engine), then build the app target in Xcode and run on a device
on the same Wi-Fi as a Chromecast/Apple TV/Kodi. Start with a plain MP4/H.264
URL (direct cast). Add ffmpeg-kit later for MKV/HEVC remux on-device.

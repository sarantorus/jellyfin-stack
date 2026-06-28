# MastCast — local build setup (macOS + Xcode)

The pure-logic core builds anywhere with SPM (`swift test`). The full iOS app
needs **a Mac with Xcode 15+** (iOS 16+ target). The repo ships an XcodeGen spec
so you don't have to hand-wire the project.

## 0. Run the engine tests (any machine with a Swift toolchain)

```sh
cd MastCast
swift test          # builds the pure-logic core + runs PlaybackPlannerTests
```

## 1. Generate the Xcode project (Mac)

```sh
brew install xcodegen          # one-time
cd MastCast
xcodegen generate              # reads project.yml → MastCast.xcodeproj
open MastCast.xcodeproj        # Xcode resolves the two SPM deps automatically
```

`project.yml` wires the app target, the `MastCast/` sources (incl. `Platform/`),
`Info.plist`, `MastCast.entitlements`, and the SPM dependencies. Set your signing
team in Xcode (Signing & Capabilities) before running on a device.

## 2. Dependencies

| Dependency        | Purpose                         | How it's wired |
| ----------------- | ------------------------------- | -------------- |
| Google Cast SDK   | Chromecast / Android TV sender  | SPM, already in `project.yml`: `https://github.com/SRGSSR/google-cast-sdk` (product `GoogleCast`). |
| GCDWebServer      | embedded HLS server             | SPM, already in `project.yml`: `https://github.com/yene/GCDWebServer`. |
| ffmpeg-kit        | ffprobe (probe) + remux         | **Manual.** Upstream `arthenica/ffmpeg-kit` was archived in 2025 with no SPM. Download a prebuilt `ffmpeg-kit-ios-full-gpl` release (or a maintained fork), unzip the `*.xcframework`s into `MastCast/Frameworks/`, then uncomment the `framework:` lines in `project.yml` and re-run `xcodegen generate`. Module name: `ffmpegkit`. |

Until ffmpeg-kit is added, the app target won't compile (the probe/remux files
`import ffmpegkit`). Everything else — Cast/AirPlay/DLNA/Roku/Kodi senders,
discovery, the engine — does not depend on it.

> **Licensing:** `ffmpeg-kit-*-gpl` builds pull in GPL components — incompatible
> with closed-source App Store distribution. For shipping, either use an
> LGPL build (no `--enable-gpl` codecs) or keep the project open-source.

## 3. Required Info.plist keys

The Cast SDK and the local server both need Local Network access on iOS 14+:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>MastCast finds and streams to TVs on your network.</string>

<!-- EVERY Bonjour service type the app browses must be listed, or iOS 14+
     silently returns no results for the missing ones. -->
<key>NSBonjourServices</key>
<array>
  <string>_googlecast._tcp</string>
  <!-- Receiver-app-scoped service; CC1AD845 is the default media receiver -->
  <string>_CC1AD845._googlecast._tcp</string>
  <string>_airplay._tcp</string>        <!-- AirPlay / Apple TV -->
  <string>_raop._tcp</string>           <!-- AirPlay audio -->
  <string>_xbmc-jsonrpc._tcp</string>   <!-- Kodi (universal-player fallback) -->
</array>
<!-- DLNA and Roku use SSDP/UDP multicast, not Bonjour, so they need no
     NSBonjourServices entry — but they still require NSLocalNetworkUsageDescription. -->

<!-- NSAllowsLocalNetworking covers the LAN HLS server with no App Store
     justification. Add per-domain HTTP exceptions only for the stream hosts you
     actually use, rather than the blanket NSAllowsArbitraryLoads. -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsLocalNetworking</key><true/>
</dict>
```

Add the **Background Modes → Audio, AirPlay, and Picture in Picture** capability
if you want playback/serving to survive backgrounding.

### Multicast entitlement (for DLNA + Roku discovery)

`SSDPDiscovery` sends to the multicast group `239.255.255.250:1900`. On iOS 14+
this requires the **multicast entitlement**
`com.apple.developer.networking.multicast`, which Apple grants on request
(https://developer.apple.com/contact/request/networking-multicast). Without it,
Cast / AirPlay / Kodi discovery (Bonjour) still work, but DLNA and Roku silently
find nothing.

### Per-transport notes

- **Kodi** (universal-player fallback): enable Settings → Services → Control →
  "Allow remote control via HTTP" (port 8080). Optional Basic auth is supported
  by `TVPlayerSender`.
- **AirPlay**: iOS has **no public API to route to a specific AirPlay device**.
  `AirPlaySender` plays via `AVPlayer`; the UI must present its `routePickerView()`
  (an `AVRoutePickerView`) so the user selects the receiver. Tapping an AirPlay
  device in the list configures playback but the user still confirms via the picker.

## 4. One-time init

`MastCastApp.init()` already calls `CastDiscovery.configureCastContext()`, which
sets up `GCKCastContext` with the default media receiver app id. Change the app id
there if you register a custom Cast receiver.

## 5. End-to-end flow (what's wired)

```
ContentView ─▶ CastCoordinator
                 ├─ CompositeDiscovery ──▶ [Receiver]
                 │     ├─ CastDiscovery   (GCKDiscoveryManager)  — Chromecast/Android TV
                 │     ├─ BonjourDiscovery (NetService)          — AirPlay, Kodi
                 │     └─ SSDPDiscovery    (multicast, entitled)  — DLNA, Roku
                 ├─ FFprobeMediaProbe (ffprobe) ─────────▶ MediaInfo
                 ├─ PlaybackPlanner ─────────────────────▶ PlaybackPlan
                 └─ execute via SenderFactory:
                      .direct        → sender.load(remoteURL)
                      .remux         → FFmpegRemuxer → GCDWebServerMediaServer → sender.load(localHLS)
                      .routeToPlayer → TVPlayerSender.load(url)  (universal player decodes natively)
                      .transcode     → surfaced (on-phone re-encode not enabled in MVP)
```

Senders by transport: `CastSender` (Google Cast), `AirPlaySender` (AVPlayer +
route picker), `DLNASender` (SOAP AVTransport), `RokuSender` (ECP Media Player),
`TVPlayerSender` (Kodi JSON-RPC).

Try it with a known-compatible URL first (an MP4/H.264 web link → `.direct`),
then an MKV/H.264+AC3 link to exercise `.remux`, then an HEVC-10bit/AV1 link with
Kodi running to exercise `.routeToPlayer`.

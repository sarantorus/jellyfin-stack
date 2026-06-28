# MastCast — Xcode setup

The pure-logic core builds with SPM (`swift test`). The full app needs an Xcode
project (iOS 16+) that compiles the `MastCast/` sources **including `Platform/`**
and links three external dependencies.

## 1. Create the app target

- New Xcode project → iOS App → SwiftUI, name `MastCast`, bundle id of your choice.
- Add the `MastCast/` source folders to the target. (The SPM `Package.swift`
  excludes `Platform/`; the Xcode app target must *include* it.)

## 2. Dependencies

| Dependency        | Purpose                         | Install |
| ----------------- | ------------------------------- | ------- |
| `google-cast-sdk` | Chromecast / Android TV sender  | SwiftPM: `https://github.com/google/CastSDK-iOS` (or CocoaPods `google-cast-sdk`). Use the no-Guest-Mode variant if you don't need it. |
| `ffmpeg-kit`      | ffprobe (probe) + remux         | The original `arthenica/ffmpeg-kit` was **archived in 2025**; use a maintained fork or self-host the `ffmpeg-kit-ios-full-gpl` xcframework. Module name: `ffmpegkit`. |
| `GCDWebServer`    | embedded HLS server             | SwiftPM: `https://github.com/swisspol/GCDWebServer` |

> **Licensing:** `ffmpeg-kit-*-gpl` builds pull in GPL components — incompatible
> with closed-source App Store distribution. For shipping, either use an
> LGPL build (no `--enable-gpl` codecs) or keep the project open-source.

## 3. Required Info.plist keys

The Cast SDK and the local server both need Local Network access on iOS 14+:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>MastCast finds and streams to TVs on your network.</string>

<key>NSBonjourServices</key>
<array>
  <string>_googlecast._tcp</string>
  <!-- Receiver-app-scoped service; CC1AD845 is the default media receiver -->
  <string>_CC1AD845._googlecast._tcp</string>
</array>

<!-- Allow plain-HTTP stream URLs and the local HLS server -->
<key>NSAppTransportSecurity</key>
<dict><key>NSAllowsArbitraryLoads</key><true/></dict>
```

Add the **Background Modes → Audio, AirPlay, and Picture in Picture** capability
if you want playback/serving to survive backgrounding.

## 4. One-time init

`MastCastApp.init()` already calls `CastDiscovery.configureCastContext()`, which
sets up `GCKCastContext` with the default media receiver app id. Change the app id
there if you register a custom Cast receiver.

## 5. End-to-end flow (what's wired)

```
ContentView ─▶ CastCoordinator
                 ├─ CastDiscovery (GCKDiscoveryManager) ──▶ [Receiver]
                 ├─ FFprobeMediaProbe (ffprobe) ─────────▶ MediaInfo
                 ├─ PlaybackPlanner ─────────────────────▶ PlaybackPlan
                 └─ execute:
                      .direct  → CastSender.load(remoteURL)
                      .remux   → FFmpegRemuxer → GCDWebServerMediaServer → CastSender.load(localHLS)
                      .routeToPlayer / .transcode  → surfaced (next milestones)
```

Try it with a known-compatible URL first (an MP4/H.264 web link → `.direct`),
then an MKV/H.264+AC3 link to exercise `.remux`.

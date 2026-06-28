# MastCast

Cast media from an iPhone to (almost) any TV — web stream URLs and local files —
handling format differences automatically, **without a server box** and
**without melting the phone**.

This is a greenfield native-iOS project. The hard part is not "casting", it is
**"any format → playable on this particular TV"**. MastCast solves that with a
remux-first, route-to-player decision engine rather than brute-force on-phone
transcoding.

---

## Why there is no "one protocol for every TV"

iPhones natively speak exactly one casting protocol: **AirPlay**. Everything
else needs the app to implement the sender side. The TV world is three
incompatible camps, so a universal caster is necessarily multi-protocol:

| Protocol        | Reaches                                          | Sender on iOS                |
| --------------- | ------------------------------------------------ | ---------------------------- |
| **AirPlay 2**   | Apple TV, Samsung/LG/Sony/Vizio (2018+)          | OS-provided (`AVPlayer`)     |
| **Google Cast** | Chromecast, Android TV, Google TV                | Google Cast SDK              |
| **DLNA/UPnP**   | Most older / budget smart TVs                    | We implement (SSDP + SOAP)   |
| **Roku ECP**    | Roku TVs & sticks                                | We implement (simple HTTP)   |
| **TV player**   | Any TV running Kodi / VLC / Infuse / Jellyfin    | App-specific control API     |

There is no "build a new protocol" or "AI model" option — a TV can only receive
languages its firmware already ships with. The work is integrating the existing
ones behind one UI and one decision engine.

## Project decisions (locked)

| Decision            | Choice                                                                 |
| ------------------- | --------------------------------------------------------------------- |
| Sender platform     | **Native iOS (Swift)** — only path to mDNS + Cast SDK + AirPlay + FFmpeg in one process |
| Cast type           | **Media casting** (play a file/URL), not live screen mirroring         |
| Content source      | Mostly **web stream URLs**, sometimes **local files** on the phone     |
| Format strategy     | **Hybrid** — native receiver when possible; TV-side player for hard codecs |
| Transcoding         | **Phone-only**, **remux-first**; heavy re-encode avoided by routing    |

## The decision ladder (core idea)

For a given (media source, target receiver) the engine picks the cheapest plan
that works:

```
1. DIRECT      remote URL the receiver can fetch & decode as-is        → phone idle
2. REMUX       video+audio codecs OK, only container/subs wrong        → cheap, phone OK
                 (repackage MKV→fMP4/HLS, no re-encode)
3. TV-PLAYER   video codec / bit-depth the native receiver can't do    → route to Kodi/VLC/etc.
                 but a universal player is on the network                  (it decodes natively)
4. TRANSCODE   nothing else works (last resort, flagged expensive)     → limited on-phone re-encode
```

Because of the Hybrid choice, step 3 absorbs the cases that would otherwise
force the unsustainable step 4. The phone never has to transcode HEVC-10bit or
AV1 when a TV-side player is available.

## Build & test

The decision engine is a pure-Swift SPM package so it runs without Xcode:

```sh
cd MastCast
swift test        # runs PlaybackPlannerTests — the decision-ladder cases
```

The full iPhone app (SwiftUI + Google Cast SDK + ffmpeg-kit) is an Xcode project
that includes these same `MastCast/` sources; the SwiftUI entry under
`MastCast/App` is excluded from the SPM target since it only builds on Apple
platforms.

## Status

**All transports + the full decision ladder wired end-to-end.** Multi-transport
discovery → probe → plan → `.direct` / `.remux` / `.routeToPlayer` → load via the
matching sender. See [SETUP.md](SETUP.md) for Xcode/dependency setup and the flow.

| Area | State |
| ---- | ----- |
| Decision engine (`Engine/PlaybackPlanner`) | ✅ implemented + unit-tested (pure SPM core) |
| Media probe (`Platform/Media/FFprobeMediaProbe`) | ✅ implemented (ffmpeg-kit) |
| Remux + local HLS server | ✅ implemented (ffmpeg-kit + GCDWebServer) |
| Discovery: Cast / AirPlay+Kodi / DLNA+Roku | ✅ Cast SDK + Bonjour + SSDP, aggregated |
| Senders: Cast / AirPlay / DLNA / Roku / Kodi | ✅ implemented |
| `.routeToPlayer` Hybrid hard-codec fallback | ✅ wired (Kodi) |
| On-phone `.transcode` (last resort) | ⏳ surfaced but not enabled (by design) |
| On-device build/run verification | ⏳ needs macOS — not run in this Linux env |

The repo separates a **pure-logic core** (`MastCast/` minus `Platform/`, builds
on any platform via SPM) from **`Platform/`** (Apple- and SDK-dependent
implementations, built only in the Xcode app target). See
[ARCHITECTURE.md](ARCHITECTURE.md) for the full design.

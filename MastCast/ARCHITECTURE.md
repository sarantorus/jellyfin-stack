# MastCast — Architecture

## 1. Data flow

```
                ┌─────────────────────────────────────────────────────────┐
                │                       iPhone (MastCast)                    │
                │                                                           │
  user picks    │   ┌──────────┐   ┌──────────┐   ┌──────────────────┐     │
  media + TV ──▶│   │ Discovery │  │  Media   │   │   PlaybackPlanner │     │
                │   │  Manager  │  │  Probe   │──▶│  (decision ladder)│     │
                │   └────┬─────┘   └────┬─────┘   └─────────┬────────┘     │
                │        │              │                   │              │
                │   receivers[]    source meta          PlaybackPlan       │
                │        │                                  │              │
                │        │            ┌─────────────────────┴───────┐      │
                │        │            ▼                             ▼      │
                │        │   ┌────────────────┐            ┌──────────────┐│
                │        │   │ LocalMediaServer│ (remux)   │   (direct)   ││
                │        │   │  + Remuxer (ff) │            └──────────────┘│
                │        │   └───────┬────────┘                            │
                │        ▼           ▼                                     │
                │   ┌─────────────────────────────────────────────┐       │
                │   │  MediaSender:  Cast | AirPlay | DLNA | Roku   │       │
                │   │               | TVPlayer (Kodi/VLC/...)       │       │
                │   └───────────────────────┬─────────────────────┘       │
                └───────────────────────────┼─────────────────────────────┘
                                            ▼
                                   TV / receiver pulls media URL & plays
```

Key principle: **media bytes flow TV ← source directly whenever possible.** The
phone only sits in the data path when it must remux (step 2) or serve a local
file. For a compatible remote URL, the phone hands over the URL and goes idle.

## 2. Modules

| Module                       | Responsibility                                                        | Implementation notes |
| ---------------------------- | --------------------------------------------------------------------- | -------------------- |
| `Discovery/DiscoveryManager` | Aggregate receivers from all transports into one `[Receiver]`         | `Network.framework` `NWBrowser` for Bonjour (`_googlecast._tcp`, `_airplay._tcp`, `_raop._tcp`); raw UDP multicast for SSDP/DLNA (`239.255.255.250:1900`); Roku via SSDP `roku:ecp` |
| `Media/MediaProbe`           | Determine source container/codecs/bit-depth/audio                     | `ffprobe` via **ffmpeg-kit-ios** (`ffmpeg-kit-ios-full-gpl`). For remote URLs, probe with `-analyzeduration`/range requests to avoid full download |
| `Engine/Capabilities`        | Per-receiver codec/container/HLS capability profiles                  | Static profiles + runtime refinement (e.g. Cast `getMediaStatus`, device model) |
| `Engine/PlaybackPlanner`     | The decision ladder → a `PlaybackPlan`                                | **Pure Swift, fully unit-tested. The crown jewel.** No I/O. |
| `Serving/LocalMediaServer`   | Embedded HTTP server exposing remuxed/local media as HLS or progressive | **GCDWebServer** (battle-tested) or **Swifter**. Serves on `0.0.0.0:<port>`; advertises phone LAN IP to the receiver |
| `Serving/Remuxer`            | Cheap container/audio remap to fMP4/HLS, no video re-encode           | ffmpeg-kit: `-c:v copy -c:a aac/copy -f hls` (or fMP4). Stream to disk/pipe as segments |
| `Senders/MediaSender`        | Protocol: `connect`, `load(url, metadata)`, transport controls        | One conformer per transport |
| `Senders/CastSender`         | Google Cast                                                           | **google-cast-sdk** (CocoaPods/SPM). `GCKCastContext`, `GCKMediaInformation` |
| `Senders/AirPlaySender`      | AirPlay                                                               | `AVPlayer` + `AVRoutePickerView`, or `MPVolumeView` route selection; load remote/local-server URL |
| `Senders/DLNASender`         | DLNA AVTransport                                                      | SOAP `SetAVTransportURI` + `Play` over the device's control URL |
| `Senders/TVPlayerSender`     | Kodi / VLC / Jellyfin client                                          | Kodi JSON-RPC `Player.Open`; VLC HTTP; Jellyfin session API. Used for the hard-codec fallback |
| `UI/*`                       | SwiftUI: receiver list, now-playing, plan badge ("Direct"/"Remuxing"/"Routed to Kodi") | Surface *why* a plan was chosen for transparency |

## 3. Capability model

```
struct Capabilities {
    var containers:  Set<String>   // "mp4","mov","m4v","mpegts" ...
    var videoCodecs: Set<String>   // "h264","hevc","vp9","av1" ...
    var audioCodecs: Set<String>   // "aac","ac3","eac3","opus" ...
    var maxBitDepth: Int           // 8 or 10
    var supportsHLS: Bool
    var canFetchRemote: Bool       // can the receiver pull an arbitrary internet URL itself?
    var isUniversalPlayer: Bool    // Kodi/VLC/Infuse/Jellyfin — decodes ~everything
}
```

Representative profiles (refined at runtime):

- **Chromecast (gen 3)**: h264 + vp9 (no hevc), 8-bit, aac/opus (no ac3/dts on basic),
  HLS yes, mp4/webm only, `canFetchRemote = true`.
- **Chromecast Ultra / Google TV 4K**: + hevc, + 10-bit, + ac3/eac3.
- **Apple TV (AirPlay)**: h264 + hevc (incl. 10-bit), aac/ac3/eac3, HLS yes, mp4/mov.
- **DLNA generic**: h264 only, 8-bit, aac/ac3, no HLS, mp4 — the most restrictive.
- **Universal player**: everything; `isUniversalPlayer = true`.

## 4. The decision ladder (formal)

Given `source: MediaInfo` and `target: Receiver`:

```
videoOK  = target.caps.videoCodecs.contains(source.videoCodec)
            && source.bitDepth <= target.caps.maxBitDepth
audioOK  = target.caps.audioCodecs.contains(source.audioCodec)
contOK   = target.caps.supportsHLS || target.caps.containers.contains(source.container)

if videoOK && audioOK && contOK && source.isRemote && target.caps.canFetchRemote:
    → .direct(source.url)                               // step 1, phone idle
elif videoOK && (target.caps.supportsHLS || canRemuxContainerFor(target)):
    → .remux(via: localServer, audio: audioOK ? .copy : .reencodeAAC)   // step 2, cheap
elif universalPlayerAvailableOnNetwork():
    → .routeToPlayer(bestUniversalPlayer)               // step 3, no phone transcode
else:
    → .transcode(profile: target.preferredEncodeProfile, warning: .expensive)  // step 4
```

`canRemuxContainerFor` is true when only the container/subs/audio differ from
what the target accepts (video stream copied verbatim). Audio is re-encoded to
AAC only when needed — that is light compared to video.

Local files skip step 1 (must be served) and start at step 2.

## 5. Hard limits to be honest about

- **Live screen mirroring to non-AirPlay TVs is out of scope** — iOS exposes no
  open API for it; only AirPlay (closed) does mirroring.
- **On-phone video re-encode (step 4) cannot sustain high-bitrate 1080p+** —
  it exists only as a flagged last resort. The Hybrid design exists precisely to
  avoid reaching it.
- **DRM-protected streams** can't be remuxed/transcoded; cast the URL directly or not at all.
- **DTS/TrueHD audio** on receivers without passthrough → re-encode audio to AAC/EAC3 (cheap), or route to a universal player for bitstream passthrough.

## 6. Build order (suggested MVP → full)

1. **Engine first** (done): `PlaybackPlanner` + `Capabilities` + tests. Pure logic, no device needed.
2. Cast path end-to-end: Discovery (Cast only) → MediaProbe → Planner → CastSender, remote URLs, `.direct` + `.remux`.
3. LocalMediaServer + Remuxer (ffmpeg-kit) — unlocks local files + remux.
4. AirPlay sender.
5. TVPlayer sender (Kodi JSON-RPC) — unlocks the Hybrid hard-codec fallback.
6. DLNA + Roku senders for long-tail TVs.
7. UI polish, plan-reason badges, queue/playlists.

## 7. Dependencies

- `ffmpeg-kit-ios` (probe + remux)  — GPL build; note App Store licensing implications.
- `google-cast-sdk`                 — Chromecast/Android TV.
- `GCDWebServer`                    — embedded HTTP/HLS server.
- Apple frameworks: `Network` (Bonjour/SSDP), `AVFoundation`/`AVKit` (AirPlay), SwiftUI.

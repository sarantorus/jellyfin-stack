import XCTest
@testable import MastCast

/// Exercises the decision ladder (ARCHITECTURE.md §4). Pure logic — no device needed.
final class PlaybackPlannerTests: XCTestCase {

    private func receiver(_ name: String, _ host: String, _ caps: Capabilities, _ t: Transport = .googleCast) -> Receiver {
        Receiver(id: name, name: name, host: host, transport: t, capabilities: caps)
    }

    private let remoteURL = URL(string: "https://example.com/movie.mkv")!
    private let localURL = URL(fileURLWithPath: "/var/mobile/Media/movie.mkv")

    // Step 1 — already-compatible remote stream goes direct.
    func testDirectForCompatibleRemoteStream() {
        let atv = receiver("Apple TV", "10.0.0.5", .airplay, .airplay)
        let source = MediaInfo(container: "mp4", videoCodec: "hevc", audioCodec: "eac3",
                               bitDepth: 10, isRemote: true)
        let planner = PlaybackPlanner(availableReceivers: [atv])
        XCTAssertEqual(planner.plan(source: source, sourceURL: remoteURL, target: atv),
                       .direct(url: remoteURL))
    }

    // Step 2 — compatible video, wrong container (MKV/H.264) → cheap remux, audio copied.
    func testRemuxForContainerOnlyMismatch() {
        let cc = receiver("Chromecast", "10.0.0.6", .chromecastBaseline)
        let source = MediaInfo(container: "mkv", videoCodec: "h264", audioCodec: "aac",
                               bitDepth: 8, isRemote: true)
        let planner = PlaybackPlanner(availableReceivers: [cc])
        XCTAssertEqual(planner.plan(source: source, sourceURL: remoteURL, target: cc),
                       .remux(audio: .copy))
    }

    // Step 2 — video fine but audio (AC3) unsupported on baseline Chromecast → remux + AAC re-encode.
    func testRemuxReencodesUnsupportedAudio() {
        let cc = receiver("Chromecast", "10.0.0.6", .chromecastBaseline)
        let source = MediaInfo(container: "mkv", videoCodec: "h264", audioCodec: "ac3",
                               bitDepth: 8, isRemote: true)
        let planner = PlaybackPlanner(availableReceivers: [cc])
        XCTAssertEqual(planner.plan(source: source, sourceURL: remoteURL, target: cc),
                       .remux(audio: .reencodeAAC))
    }

    // Step 3 — HEVC-10bit to a baseline Chromecast that can't decode it, but Kodi is on the
    // same TV host → route to the universal player instead of transcoding on the phone.
    func testRouteToUniversalPlayerForHardCodec() {
        let cc = receiver("Chromecast", "10.0.0.6", .chromecastBaseline)
        let kodi = receiver("Kodi", "10.0.0.6", .universalPlayer, .tvPlayer)
        let source = MediaInfo(container: "mkv", videoCodec: "hevc", audioCodec: "dts",
                               bitDepth: 10, isRemote: true)
        let planner = PlaybackPlanner(availableReceivers: [cc, kodi])
        XCTAssertEqual(planner.plan(source: source, sourceURL: remoteURL, target: cc),
                       .routeToPlayer(receiver: kodi))
    }

    // Step 4 — same hard codec, but no universal player on the network → flagged phone transcode.
    func testTranscodeLastResortWhenNoPlayer() {
        let cc = receiver("Chromecast", "10.0.0.6", .chromecastBaseline)
        let source = MediaInfo(container: "mkv", videoCodec: "av1", audioCodec: "opus",
                               bitDepth: 10, isRemote: true)
        let planner = PlaybackPlanner(availableReceivers: [cc])
        XCTAssertEqual(planner.plan(source: source, sourceURL: remoteURL, target: cc),
                       .transcode(profile: .h264_8bit, warning: .expensiveOnPhone))
    }

    // Local file is never .direct — it must be served, so a compatible file still goes through remux.
    func testLocalFileNeverDirect() {
        let atv = receiver("Apple TV", "10.0.0.5", .airplay, .airplay)
        let source = MediaInfo(container: "mp4", videoCodec: "hevc", audioCodec: "aac",
                               bitDepth: 10, isRemote: false)
        let planner = PlaybackPlanner(availableReceivers: [atv])
        XCTAssertEqual(planner.plan(source: source, sourceURL: localURL, target: atv),
                       .remux(audio: .copy))
    }

    // DRM stream that the target can play directly → direct; otherwise unsupported.
    func testDRMOnlyDirectOrUnsupported() {
        let cc = receiver("Chromecast", "10.0.0.6", .chromecastBaseline)
        let playable = MediaInfo(container: "mp4", videoCodec: "h264", audioCodec: "aac",
                                 bitDepth: 8, isRemote: true, isDRMProtected: true)
        let unplayable = MediaInfo(container: "mkv", videoCodec: "hevc", audioCodec: "dts",
                                   bitDepth: 10, isRemote: true, isDRMProtected: true)
        let planner = PlaybackPlanner(availableReceivers: [cc])
        XCTAssertEqual(planner.plan(source: playable, sourceURL: remoteURL, target: cc),
                       .direct(url: remoteURL))
        if case .unsupported = planner.plan(source: unplayable, sourceURL: remoteURL, target: cc) {
            // expected
        } else {
            XCTFail("DRM with no compatible direct path must be .unsupported")
        }
    }
}

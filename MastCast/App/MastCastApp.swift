import SwiftUI

/// App entry point. The UI is intentionally thin: pick media → pick receiver →
/// the engine decides the plan and the matching sender executes it. The chosen
/// `PlaybackPlan` is surfaced as a badge ("Direct" / "Remuxing" / "Routed to Kodi")
/// so the user always sees *why* playback behaves the way it does.
@main
struct MastCastApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        // TODO: ReceiverListView (DiscoveryManager) + MediaPickerView + NowPlayingView.
        Text("MastCast")
            .font(.largeTitle)
    }
}

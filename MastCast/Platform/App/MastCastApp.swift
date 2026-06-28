import SwiftUI

/// App entry point. Thin UI: enter a stream URL → pick a discovered receiver →
/// the engine decides the plan and the matching sender executes it. The chosen
/// `PlaybackPlan` is shown as a badge so the user sees *why* playback behaves the
/// way it does.
@main
struct MastCastApp: App {
    init() { CastDiscovery.configureCastContext() }   // one-time Cast SDK setup
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @StateObject private var coordinator = CastCoordinator()
    @State private var urlString = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Media") {
                    TextField("Stream URL or file path", text: $urlString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Receivers") {
                    if coordinator.receivers.isEmpty {
                        Text("Searching for TVs…").foregroundStyle(.secondary)
                    }
                    ForEach(coordinator.receivers) { receiver in
                        Button {
                            Task { await coordinator.cast(urlString, to: receiver, title: title(from: urlString)) }
                        } label: {
                            HStack {
                                Image(systemName: icon(for: receiver.transport))
                                VStack(alignment: .leading) {
                                    Text(receiver.name)
                                    Text(receiver.transport.rawValue).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(urlString.isEmpty)
                    }
                }

                Section("Status") {
                    Text(statusText).foregroundStyle(statusColor)
                    if let plan = coordinator.planDescription {
                        Label(plan, systemImage: "wand.and.stars").font(.caption)
                    }
                    if coordinator.status == .playing {
                        Button("Stop", role: .destructive) { Task { await coordinator.stop() } }
                    }
                }
            }
            .navigationTitle("MastCast")
            .onAppear { coordinator.startDiscovery() }
            .onDisappear { coordinator.stopDiscovery() }
        }
    }

    private var statusText: String {
        switch coordinator.status {
        case .idle: return "Ready"
        case .discovering: return "Discovering receivers…"
        case .probing: return "Probing media…"
        case .casting: return "Connecting & loading…"
        case .playing: return "Playing"
        case .failed(let m): return "Failed: \(m)"
        }
    }

    private var statusColor: Color {
        if case .failed = coordinator.status { return .red }
        if coordinator.status == .playing { return .green }
        return .primary
    }

    private func icon(for t: Transport) -> String {
        switch t {
        case .googleCast: return "tv"
        case .airplay: return "airplayvideo"
        case .dlna: return "play.tv"
        case .roku: return "tv.inset.filled"
        case .tvPlayer: return "play.rectangle.on.rectangle"
        }
    }

    private func title(from url: String) -> String {
        URL(string: url)?.lastPathComponent ?? "MastCast"
    }
}

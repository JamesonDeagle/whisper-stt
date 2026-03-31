import SwiftUI
import AppKit

@main
struct MurmurApp: App {
    @ObservedObject private var appState = AppState.shared
    @NSApplicationDelegateAdaptor(MurmurDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra("Murmur", systemImage: "waveform") {
            MenuBarView()
                .environmentObject(appState)
        }
    }
}

class MurmurDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    func applicationDidFinishLaunching(_ notification: Notification) {
        mlog("applicationDidFinishLaunching")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task { @MainActor in
                AppState.shared.startSetup()
            }
        }
    }
}

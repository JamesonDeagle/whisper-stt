import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.state {
            case .loading:
                Label("Loading model...", systemImage: "hourglass")
                    .disabled(true)
            case .idle:
                Text("Option+Space — record / stop")
                    .disabled(true)
                Text("Escape — cancel")
                    .disabled(true)
            case .recording:
                Label("Recording...", systemImage: "mic.fill")
                    .disabled(true)
            case .transcribing:
                Label("Transcribing...", systemImage: "brain")
                    .disabled(true)
            }

            Divider()

            Menu("Model") {
                Button {
                    appState.activeModel = "turbo"
                    Task { await appState.engine.loadModel(name: "turbo") }
                } label: {
                    if appState.activeModel == "turbo" {
                        Label("turbo (fast)", systemImage: "checkmark")
                    } else {
                        Text("turbo (fast)")
                    }
                }
                .disabled(appState.state != .idle)
                Button {
                    appState.activeModel = "large"
                    Task { await appState.engine.loadModel(name: "large") }
                } label: {
                    if appState.activeModel == "large" {
                        Label("large (best quality)", systemImage: "checkmark")
                    } else {
                        Text("large (best quality)")
                    }
                }
                .disabled(appState.state != .idle)
            }

            Menu("Microphone") {
                let devices = InputDeviceManager.availableInputDevices()
                ForEach(devices) { device in
                    Button {
                        appState.selectInputDevice(device)
                    } label: {
                        if device.uid == appState.selectedInputDeviceUID {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Text(device.name)
                        }
                    }
                    .disabled(appState.state != .idle)
                }
            }

            Divider()

            Button("Quit Murmur") {
                HotkeyManager.shared.unregister()
                Task { await appState.engine.cleanup() }
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

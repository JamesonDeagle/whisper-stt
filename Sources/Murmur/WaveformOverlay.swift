import SwiftUI
import AppKit

@MainActor
class WaveformPanel: ObservableObject {
    private var panel: NSPanel?
    @Published var isVisible = false
    @Published var mode: WaveformMode = .recording
    @Published var levels: [Float] = Array(repeating: 0.15, count: 11)

    enum WaveformMode {
        case recording
        case transcribing
    }

    func show() {
        if panel == nil { createPanel() }
        mode = .recording
        panel?.orderFront(nil)
        isVisible = true
    }

    func hide() {
        isVisible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.panel?.orderOut(nil)
        }
    }

    func setTranscribing() {
        mode = .transcribing
    }

    func updateLevels(_ newLevels: [Float]) {
        levels = newLevels
    }

    private func createPanel() {
        guard let screen = NSScreen.main else { return }

        let width: CGFloat = 260
        let height: CGFloat = 140
        let bottomMargin: CGFloat = 60

        let x = screen.frame.midX - width / 2
        let y = screen.frame.minY + bottomMargin

        let frame = NSRect(x: x, y: y, width: width, height: height)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostView = NSHostingView(rootView:
            WaveformView()
                .environmentObject(self)
        )
        hostView.frame = panel.contentView!.bounds
        hostView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hostView)

        self.panel = panel
    }
}

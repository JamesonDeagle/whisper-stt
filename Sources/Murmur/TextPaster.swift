import AppKit
import Carbon

enum TextPaster {
    static func paste(_ text: String) {
        mlog("TextPaster: paste called with '\(text.prefix(50))'")

        let pasteboard = NSPasteboard.general
        let prev = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let verify = pasteboard.string(forType: .string)
        mlog("TextPaster: clipboard set, verify='\(verify?.prefix(50) ?? "nil")'")

        // Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 'v'
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

        mlog("TextPaster: CGEventSource=\(source != nil), keyDown=\(keyDown != nil), keyUp=\(keyUp != nil)")

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        mlog("TextPaster: Cmd+V posted, trusted=\(AXIsProcessTrusted())")

        // Restore clipboard after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let prev = prev {
                pasteboard.clearContents()
                pasteboard.setString(prev, forType: .string)
            }
        }
    }
}

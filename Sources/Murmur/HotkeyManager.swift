import Carbon
import AppKit

final class HotkeyManager: @unchecked Sendable {
    private var hotkeyRef: EventHotKeyRef?
    private var onToggle: (() -> Void)?
    private var eventHandler: EventHandlerRef?

    static let shared = HotkeyManager()

    func register(modifiers: UInt32 = UInt32(optionKey), keyCode: UInt32 = 49, onToggle: @escaping () -> Void) {
        // keyCode 49 = Space, optionKey = Option
        self.onToggle = onToggle
        unregister()

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4D555252) // "MURR"
        hotKeyID.id = 1

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let refPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                mgr.onToggle?()
                return noErr
            },
            1,
            &eventType,
            refPtr,
            &eventHandler
        )

        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotkeyRef)
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}

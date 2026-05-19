import Carbon

final class HotKeyManager {
    private let modifierFlags: UInt32
    private let keyCode: UInt32
    private let handler: () -> Void
    private var eventHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(modifierFlags: UInt32, keyCode: UInt32, handler: @escaping () -> Void) {
        self.modifierFlags = modifierFlags
        self.keyCode = keyCode
        self.handler = handler
    }

    func register() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handler()
            return noErr
        }

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &eventSpec, userData, &eventHandlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x4C505242), id: 1)
        RegisterEventHotKey(keyCode, modifierFlags, hotKeyID, GetEventDispatcherTarget(), 0, &eventHotKeyRef)
    }

    func tearDown() {
        if let eventHotKeyRef {
            UnregisterEventHotKey(eventHotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}


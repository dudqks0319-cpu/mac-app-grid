import Carbon

final class HotKeyManager {
    private static let hotKeySignature = OSType(0x4D414744)

    private let modifierFlags: UInt32
    private let keyCode: UInt32
    private let hotKeyIDValue: UInt32
    private let handler: () -> Void
    private var eventHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(modifierFlags: UInt32, keyCode: UInt32, hotKeyID: UInt32 = 1, handler: @escaping () -> Void) {
        self.modifierFlags = modifierFlags
        self.keyCode = keyCode
        self.hotKeyIDValue = hotKeyID
        self.handler = handler
    }

    @discardableResult
    func register() -> OSStatus {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            var pressedHotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &pressedHotKeyID
            )
            guard status == noErr,
                  pressedHotKeyID.signature == HotKeyManager.hotKeySignature,
                  pressedHotKeyID.id == manager.hotKeyIDValue
            else { return noErr }
            manager.handler()
            return noErr
        }

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let handlerStatus = InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &eventSpec, userData, &eventHandlerRef)
        guard handlerStatus == noErr else { return handlerStatus }

        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: hotKeyIDValue)
        let registerStatus = RegisterEventHotKey(keyCode, modifierFlags, hotKeyID, GetEventDispatcherTarget(), 0, &eventHotKeyRef)
        if registerStatus != noErr, let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        return registerStatus
    }

    func tearDown() {
        if let eventHotKeyRef {
            UnregisterEventHotKey(eventHotKeyRef)
            self.eventHotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }
}

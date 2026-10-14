import Carbon

/// Thin wrapper over Carbon global hot keys. They need no Accessibility
/// permission and win over the shortcuts of the app in front.
@MainActor
final class HotkeyCenter {
    static let shared = HotkeyCenter()

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false
    /// "ATJY"
    private static let signature: OSType = 0x41544A59

    private func installHandler() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKey = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
            guard status == noErr, hotKey.signature == HotkeyCenter.signature else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated { HotkeyCenter.shared.fire(hotKey.id) }
            return noErr
        }, 1, &spec, nil, nil)
        handlerInstalled = status == noErr
    }

    /// Registers `keyCode` + Carbon `modifiers` (cmdKey, shiftKey…). Returns false if
    /// another app already owns that combination.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> Bool {
        installHandler()
        let id = nextID
        nextID &+= 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, EventHotKeyID(signature: Self.signature, id: id),
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        refs[id] = ref
        actions[id] = action
        return true
    }

    func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs.removeAll()
        actions.removeAll()
    }

    var isEmpty: Bool { refs.isEmpty }

    private func fire(_ id: UInt32) {
        actions[id]?()
    }
}

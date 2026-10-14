import Carbon

/// Thin wrapper over Carbon global hot keys. They need no Accessibility
/// permission and win over the shortcuts of the app in front.
@MainActor
final class HotkeyCenter {
    static let shared = HotkeyCenter()

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var releases: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false
    /// "ATJY"
    private static let signature: OSType = 0x41544A59

    private func installHandler() {
        guard !handlerInstalled else { return }
        var specs = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKey = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
            guard status == noErr, hotKey.signature == HotkeyCenter.signature else { return OSStatus(eventNotHandledErr) }
            let released = GetEventKind(event) == UInt32(kEventHotKeyReleased)
            MainActor.assumeIsolated { HotkeyCenter.shared.fire(hotKey.id, released: released) }
            return noErr
        }, specs.count, &specs, nil, nil)
        handlerInstalled = status == noErr
    }

    /// Registers `keyCode` + Carbon `modifiers` (cmdKey, shiftKey…). Returns its ID, or nil
    /// if another app already owns that combination. `onRelease` runs when the key goes up.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, onRelease: (() -> Void)? = nil,
                  action: @escaping () -> Void) -> UInt32? {
        installHandler()
        let id = nextID
        nextID &+= 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, EventHotKeyID(signature: Self.signature, id: id),
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return nil }
        refs[id] = ref
        actions[id] = action
        releases[id] = onRelease
        return id
    }

    func unregister(_ ids: [UInt32]) {
        for id in ids {
            if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
            actions[id] = nil
            releases[id] = nil
        }
    }

    func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs.removeAll()
        actions.removeAll()
        releases.removeAll()
    }

    var isEmpty: Bool { refs.isEmpty }

    private func fire(_ id: UInt32, released: Bool) {
        if released {
            releases[id]?()
        } else {
            actions[id]?()
        }
    }
}

import AppKit
import Carbon

/// Device-dependent modifier bits (IOKit's NX_DEVICE*KEYMASK). `NSEvent.modifierFlags`
/// carries them, which is how left and right keys are told apart.
enum DeviceFlags {
    static let leftShift: UInt = 0x02
    static let rightShift: UInt = 0x04
    static let leftCommand: UInt = 0x08
    static let rightCommand: UInt = 0x10
    static let leftOption: UInt = 0x20
    static let rightOption: UInt = 0x40
}

/// Watches the trigger key and turns trigger + key into app switching.
///
/// While the trigger is held, letters are registered as Carbon hot keys (⌘ + letter,
/// ⌘⇧ + letter…) and released again when it goes up, so normal shortcuts typed with
/// the left key are never touched. Watching modifiers and Carbon hot keys need no
/// Accessibility permission; only window cycling does.
@MainActor
final class Switcher: ObservableObject {
    static let shared = Switcher()

    @Published private(set) var triggerHeld = false
    private var monitors: [Any] = []
    private var deviceFlags: UInt = 0
    private var switcherTask: DispatchWorkItem?
    /// Letter shared by several apps, held down: a tap when it goes up, the chooser if it stays.
    private var heldKey: String?
    private var holdTask: DispatchWorkItem?
    /// Open chooser, the extra hot keys it registered (arrows, digits, return, escape…)
    /// and the mouse monitor that closes it on a click elsewhere.
    private var chooser: ChooserModel?
    private var chooserHotkeys: [UInt32] = []
    private var chooserMouseMonitor: Any?

    private var settings: Settings { .shared }
    private var catalog: AppCatalog { .shared }

    func start() {
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.flagsChanged(event) }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.flagsChanged(event) }
            return event
        }) {
            monitors.append(local)
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { KeyboardLayout.reset() }
        }
    }

    // MARK: Trigger

    private func flagsChanged(_ event: NSEvent) {
        deviceFlags = event.modifierFlags.rawValue
        let held = !settings.paused && isTriggerDown(deviceFlags)
        guard held != triggerHeld else { return }
        triggerHeld = held
        if held { arm() } else { disarm() }
    }

    /// Right key down and its left twin up (both together is a normal shortcut).
    private func isTriggerDown(_ flags: UInt) -> Bool {
        switch settings.trigger {
        case .rightCommand:
            return flags & DeviceFlags.rightCommand != 0 && flags & DeviceFlags.leftCommand == 0
        case .rightOption:
            return flags & DeviceFlags.rightOption != 0 && flags & DeviceFlags.leftOption == 0
        }
    }

    private var triggerModifier: UInt32 { settings.trigger == .rightCommand ? UInt32(cmdKey) : UInt32(optionKey) }
    /// The modifier that turns a letter into "assign to the front app".
    var assignModifierSymbol: String { settings.trigger == .rightCommand ? "⌥" : "⌘" }
    private var assignModifier: UInt32 { settings.trigger == .rightCommand ? UInt32(optionKey) : UInt32(cmdKey) }

    private func arm() {
        let hotkeys = HotkeyCenter.shared
        hotkeys.unregisterAll()
        cancelHold()
        chooserHotkeys = []
        let base = triggerModifier
        let withShift = settings.enableCycleHotkey || settings.enableHideOthersHotkey
        for key in Keys.all where !settings.ignoredKeys.contains(key) {
            guard let code = KeyboardLayout.keyCode(for: key) else { continue }
            hotkeys.register(keyCode: code, modifiers: base, onRelease: { [weak self] in self?.released(key) }) { [weak self] in
                self?.pressed(key, shift: false)
            }
            if withShift {
                hotkeys.register(keyCode: code, modifiers: base | UInt32(shiftKey)) { [weak self] in self?.pressed(key, shift: true) }
            }
            if settings.enableAssignHotkey {
                hotkeys.register(keyCode: code, modifiers: base | assignModifier) { [weak self] in self?.assignFrontApp(to: key) }
            }
        }
        if !settings.hideKey.isEmpty, let code = KeyboardLayout.keyCode(for: settings.hideKey) {
            hotkeys.register(keyCode: code, modifiers: base) { [weak self] in self?.hideFrontApp() }
            hotkeys.register(keyCode: code, modifiers: base | UInt32(shiftKey)) { [weak self] in self?.hideOtherApps() }
        }

        // The chooser stays open across trigger presses; its keys must come back.
        if chooser != nil { registerChooserKeys() }

        switcherTask?.cancel()
        if settings.showSwitcher, chooser == nil {
            let task = DispatchWorkItem { [weak self] in
                guard let self, self.triggerHeld else { return }
                SwitcherPanel.shared.show()
            }
            switcherTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + settings.switcherDelay, execute: task)
        }
    }

    private func disarm() {
        HotkeyCenter.shared.unregisterAll()
        chooserHotkeys = []
        switcherTask?.cancel()
        if chooser != nil {
            // Stays open after letting go of the trigger, until a pick or escape.
            registerChooserKeys()
        } else {
            SwitcherPanel.shared.hide()
        }
        // Trigger let go before the letter: still a tap.
        if let key = heldKey {
            cancelHold()
            focus(key: key, hideOthers: settings.alwaysHideOthers)
        }
    }

    /// Re-register after settings change while the trigger is down (rare, but cheap).
    func reload() {
        if triggerHeld { arm() }
    }

    // MARK: Actions

    private func pressed(_ key: String, shift: Bool) {
        if let chooser {
            if key == chooser.key {
                moveChooser(shift ? -1 : 1)
                return
            }
            if !shift, let number = Int(key), (1...min(chooser.apps.count, 9)).contains(number) {
                chooser.selection = number - 1
                confirmChooser()
                return
            }
            closeChooser()
        }
        // Key repeat of the letter being held: keep waiting.
        if heldKey == key { return }
        // Another key while a letter is still down: that letter was a tap.
        if let held = heldKey {
            cancelHold()
            focus(key: held, hideOthers: settings.alwaysHideOthers)
        }
        switcherTask?.cancel()
        SwitcherPanel.shared.hide()
        if !shift, settings.showChooser, catalog.candidates(for: key).count > 1 {
            holdForChooser(key)
            return
        }
        let rightShift = shift && deviceFlags & DeviceFlags.rightShift != 0
        let leftShift = shift && !rightShift
        focus(key: key,
              forceCycle: rightShift && settings.enableCycleHotkey,
              hideOthers: settings.alwaysHideOthers || (leftShift && settings.enableHideOthersHotkey))
    }

    // MARK: Chooser

    /// Wait to see whether `key` is tapped (act on release) or held (open the chooser).
    private func holdForChooser(_ key: String) {
        heldKey = key
        let task = DispatchWorkItem { [weak self] in
            guard let self, self.heldKey == key else { return }
            self.heldKey = nil
            self.openChooser(for: key)
        }
        holdTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.chooserDelay, execute: task)
    }

    private func released(_ key: String) {
        guard heldKey == key else { return }
        cancelHold()
        focus(key: key, hideOthers: settings.alwaysHideOthers)
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        heldKey = nil
    }

    private func openChooser(for key: String) {
        let apps = catalog.candidates(for: key)
        guard apps.count > 1 else {
            focus(key: key, hideOthers: settings.alwaysHideOthers)
            return
        }
        // Start on the app after the one in front, as ⌘⇥ does.
        let frontID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let selection = apps.firstIndex { $0.bundleID == frontID }.map { ($0 + 1) % apps.count } ?? 0
        let model = ChooserModel(key: key, apps: apps, selection: selection)
        model.onPick = { [weak self] index in
            self?.chooser?.selection = index
            self?.confirmChooser()
        }
        chooser = model
        registerChooserKeys()
        chooserMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeChooser() }
        }
        SwitcherPanel.shared.choose(model)
    }

    /// Keys that drive the open chooser, with and without the trigger held. Without it
    /// they are plain keys, taken from every app until the chooser closes.
    private func registerChooserKeys() {
        guard let chooser else { return }
        let hotkeys = HotkeyCenter.shared
        hotkeys.unregister(chooserHotkeys)
        chooserHotkeys = []

        let keys: [(Int, () -> Void)] = [
            (kVK_LeftArrow, { [weak self] in self?.moveChooser(-1) }),
            (kVK_UpArrow, { [weak self] in self?.moveChooser(-1) }),
            (kVK_RightArrow, { [weak self] in self?.moveChooser(1) }),
            (kVK_DownArrow, { [weak self] in self?.moveChooser(1) }),
            (kVK_Tab, { [weak self] in self?.moveChooser(1) }),
            (kVK_Return, { [weak self] in self?.confirmChooser() }),
            (kVK_ANSI_KeypadEnter, { [weak self] in self?.confirmChooser() }),
            (kVK_Escape, { [weak self] in self?.closeChooser() }),
        ]
        for modifiers in [0, triggerModifier] {
            chooserHotkeys += keys.compactMap { code, action in
                hotkeys.register(keyCode: UInt32(code), modifiers: modifiers, action: action)
            }
        }
        // With the trigger held, the letter and digits already reach `pressed`.
        if let code = KeyboardLayout.keyCode(for: chooser.key) {
            let next = hotkeys.register(keyCode: code, modifiers: 0) { [weak self] in self?.moveChooser(1) }
            let back = hotkeys.register(keyCode: code, modifiers: UInt32(shiftKey)) { [weak self] in self?.moveChooser(-1) }
            chooserHotkeys += [next, back].compactMap { $0 }
        }
        for number in 1...min(chooser.apps.count, 9) {
            guard let code = KeyboardLayout.keyCode(for: String(number)) else { continue }
            let id = hotkeys.register(keyCode: code, modifiers: 0) { [weak self] in
                self?.chooser?.onPick?(number - 1)
            }
            if let id { chooserHotkeys.append(id) }
        }
    }

    private func moveChooser(_ step: Int) {
        guard let chooser else { return }
        let count = chooser.apps.count
        chooser.selection = ((chooser.selection + step) % count + count) % count
    }

    private func confirmChooser() {
        guard let chooser else { return }
        let app = chooser.apps[chooser.selection]
        closeChooser()
        open(app, hideOthers: settings.alwaysHideOthers)
    }

    private func closeChooser() {
        HotkeyCenter.shared.unregister(chooserHotkeys)
        chooserHotkeys = []
        chooser = nil
        if let chooserMouseMonitor { NSEvent.removeMonitor(chooserMouseMonitor) }
        chooserMouseMonitor = nil
        SwitcherPanel.shared.hide()
    }

    // MARK: Focus

    /// Focus the app behind `key`, or do its "already focused" action.
    func focus(key: String, forceCycle: Bool = false, hideOthers: Bool = false) {
        let candidates = catalog.candidates(for: key)
        guard !candidates.isEmpty else {
            NSSound.beep()
            return
        }
        let assigned = settings.assignments[key]
        guard let front = NSWorkspace.shared.frontmostApplication,
              let frontID = front.bundleIdentifier,
              candidates.contains(where: { $0.bundleID == frontID }) else {
            open(candidates[0], hideOthers: hideOthers)
            return
        }

        // Running apps reachable by cycling, in order.
        var ring = candidates.filter { catalog.runningApp($0.bundleID) != nil }
        if settings.excludeStaticFromCycle, let assigned, assigned.bundleID != frontID {
            ring.removeAll { $0.bundleID == assigned.bundleID }
        }
        let next: AppRef? = {
            guard ring.count > 1, let index = ring.firstIndex(where: { $0.bundleID == frontID }) else { return nil }
            return ring[(index + 1) % ring.count]
        }()

        if forceCycle {
            if let next { open(next, hideOthers: hideOthers) }
            return
        }

        let action = assigned?.bundleID == frontID ? assigned!.whenFocused : settings.dynamicFocusedAction
        switch action {
        case .hide:
            front.hide()
        case .expose:
            Windows.showAppExpose()
        case .cycleApps:
            if let next {
                open(next, hideOthers: hideOthers)
            } else {
                front.hide()
            }
        case .cycleWindows:
            if !Windows.cycle(front), !Windows.isTrusted {
                Windows.requestAccess()
            }
        }
    }

    /// Bring `app` to the front, launching it if needed.
    func open(_ app: AppRef, hideOthers: Bool = false) {
        if let running = catalog.runningApp(app.bundleID) {
            // Same sequence rcmd uses: plain activate, then activate on behalf of this
            // app (macOS 14 cooperative activation), then unhide.
            let options: NSApplication.ActivationOptions = settings.activateAllWindows ? [.activateAllWindows] : []
            running.activate(options: options)
            running.activate(from: .current, options: options)
            if running.isHidden { running.unhide() }
            if !Windows.hasWindowOnScreen(pid: running.processIdentifier), let url = running.bundleURL {
                // Nothing visible in this Space: reopen like the Dock does (unminimizes or opens a window).
                reopen(url)
            }
            if hideOthers { hideApps(except: running.processIdentifier) }
        } else if let url = app.resolvedURL {
            reopen(url) { launched in
                if hideOthers, let launched { self.hideApps(except: launched.processIdentifier) }
            }
        } else {
            NSSound.beep()
        }
    }

    private func reopen(_ url: URL, completion: ((NSRunningApplication?) -> Void)? = nil) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
            if let error { NSLog("Atajoly: could not open \(url.path): \(error)") }
            DispatchQueue.main.async { completion?(app) }
        }
    }

    private func hideApps(except pid: pid_t) {
        for app in catalog.running where app.processIdentifier != pid && !app.isHidden {
            app.hide()
        }
    }

    private func assignFrontApp(to key: String) {
        switcherTask?.cancel()
        if chooser != nil { closeChooser() }
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.bundleIdentifier != Bundle.main.bundleIdentifier,
              let ref = AppRef(running: front) else {
            NSSound.beep()
            return
        }
        if settings.assignments[key]?.bundleID == ref.bundleID {
            settings.unassign(key)
            SwitcherPanel.shared.flash(key: key, app: ref, message: tr("Tecla liberada"))
        } else {
            settings.assign(ref, to: key)
            SwitcherPanel.shared.flash(key: key, app: ref, message: tr("Asignada a %@", ref.name))
        }
    }

    private func hideFrontApp() {
        switcherTask?.cancel()
        if chooser != nil { closeChooser() }
        SwitcherPanel.shared.hide()
        NSWorkspace.shared.frontmostApplication?.hide()
    }

    private func hideOtherApps() {
        switcherTask?.cancel()
        if chooser != nil { closeChooser() }
        SwitcherPanel.shared.hide()
        guard let front = NSWorkspace.shared.frontmostApplication else { return }
        hideApps(except: front.processIdentifier)
    }
}

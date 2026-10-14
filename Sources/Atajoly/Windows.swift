import AppKit
import ApplicationServices

/// Window-level helpers. Cycling windows uses the Accessibility API and needs the
/// user's permission; everything else works without it.
enum Windows {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that leads to Privacy & Security → Accessibility.
    static func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// Does `pid` have a normal window visible in the current Space?
    /// Reads only owner and layer, which need no Screen Recording permission.
    static func hasWindowOnScreen(pid: pid_t) -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return true }
        return list.contains {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == pid && ($0[kCGWindowLayer as String] as? Int) == 0
        }
    }

    /// Raises the back-most standard window of `app`, so repeated calls walk
    /// through all of them. Returns false when there is nothing to cycle.
    @discardableResult
    static func cycle(_ app: NSRunningApplication) -> Bool {
        guard isTrusted else { return false }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return false }
        let usable = windows.filter { window in
            attribute(window, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole as String
                && attribute(window, kAXMinimizedAttribute) as? Bool != true
        }
        guard usable.count > 1, let target = usable.last else { return false }
        AXUIElementPerformAction(target, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(target, kAXMainAttribute as CFString, kCFBooleanTrue)
        app.activate()
        return true
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> Any? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    /// App Exposé for the front app, through the Dock's private notification
    /// (looked up at runtime so a missing symbol only disables this action).
    static func showAppExpose() {
        typealias SendNotification = @convention(c) (CFString, Int32) -> Void
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CoreDockSendNotification") else {
            NSSound.beep()
            return
        }
        let send = unsafeBitCast(symbol, to: SendNotification.self)
        send("com.apple.expose.front.awake" as CFString, 0)
    }
}

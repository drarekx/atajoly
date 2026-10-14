import Foundation
import ServiceManagement

/// Modifier held to turn letters into app shortcuts. Only the right-hand keys,
/// so the left ones keep working as usual.
enum TriggerKey: String, CaseIterable, Identifiable {
    case rightCommand, rightOption
    var id: String { rawValue }

    var title: String {
        switch self {
        case .rightCommand: return tr("⌘ derecho")
        case .rightOption: return tr("⌥ derecho")
        }
    }

    var symbol: String {
        switch self {
        case .rightCommand: return "⌘"
        case .rightOption: return "⌥"
        }
    }
}

/// What a shortcut does when its app is already in front.
enum FocusedAction: Int, Codable, CaseIterable, Identifiable {
    case hide = 0, expose = 1, cycleApps = 2, cycleWindows = 3
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .hide: return tr("Ocultar la app")
        case .expose: return tr("Mostrar sus ventanas (Exposé)")
        case .cycleApps: return tr("Pasar a la siguiente app con la misma letra")
        case .cycleWindows: return tr("Pasar a la siguiente ventana")
        }
    }
}

/// Look of the on-screen switcher shown while the trigger is held.
enum SwitcherLayout: String, CaseIterable, Identifiable {
    case compact, comfortable
    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: return tr("Compacto")
        case .comfortable: return tr("Amplio")
        }
    }
}

/// User preferences, persisted in UserDefaults.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    @Published var trigger: TriggerKey { didSet { defaults.set(trigger.rawValue, forKey: "trigger") } }
    /// Shortcuts switched off from the menu.
    @Published var paused: Bool { didSet { defaults.set(paused, forKey: "paused") } }
    /// Key → app chosen by the user. Wins over the apps that are running.
    @Published var assignments: [String: StaticAssignment] { didSet { save(assignments, "assignments") } }
    /// Keys Atajoly leaves alone (so ⌘ derecho + C still copies, for example).
    @Published var ignoredKeys: Set<String> { didSet { save(ignoredKeys, "ignoredKeys") } }
    /// Bundle IDs never given a letter automatically.
    @Published var ignoredApps: Set<String> { didSet { save(ignoredApps, "ignoredApps") } }
    /// What automatic (running-app) letters do when their app is already in front.
    @Published var dynamicFocusedAction: FocusedAction {
        didSet { defaults.set(dynamicFocusedAction.rawValue, forKey: "dynamicFocusedAction") }
    }
    /// Trigger + other modifier + letter assigns the letter to the front app.
    @Published var enableAssignHotkey: Bool { didSet { defaults.set(enableAssignHotkey, forKey: "enableAssignHotkey") } }
    /// Trigger + right ⇧ + letter always moves to the next app with that letter.
    @Published var enableCycleHotkey: Bool { didSet { defaults.set(enableCycleHotkey, forKey: "enableCycleHotkey") } }
    /// Trigger + left ⇧ + letter focuses the app and hides the rest.
    @Published var enableHideOthersHotkey: Bool { didSet { defaults.set(enableHideOthersHotkey, forKey: "enableHideOthersHotkey") } }
    @Published var alwaysHideOthers: Bool { didSet { defaults.set(alwaysHideOthers, forKey: "alwaysHideOthers") } }
    /// Bring every window of the app forward, not just the last one used.
    @Published var activateAllWindows: Bool { didSet { defaults.set(activateAllWindows, forKey: "activateAllWindows") } }
    /// Cycling through running apps skips the one assigned by hand to that key.
    @Published var excludeStaticFromCycle: Bool { didSet { defaults.set(excludeStaticFromCycle, forKey: "excludeStaticFromCycle") } }
    /// Trigger + this key hides the front app ("" = off).
    @Published var hideKey: String { didSet { defaults.set(hideKey, forKey: "hideKey") } }
    @Published var showSwitcher: Bool { didSet { defaults.set(showSwitcher, forKey: "showSwitcher") } }
    /// Seconds the trigger must be held before the switcher appears.
    @Published var switcherDelay: Double { didSet { defaults.set(switcherDelay, forKey: "switcherDelay") } }
    @Published var switcherLayout: SwitcherLayout { didSet { defaults.set(switcherLayout.rawValue, forKey: "switcherLayout") } }
    @Published var hideMenuBarIcon: Bool { didSet { defaults.set(hideMenuBarIcon, forKey: "hideMenuBarIcon") } }

    private init() {
        defaults.register(defaults: [
            "dynamicFocusedAction": FocusedAction.cycleApps.rawValue,
            "enableAssignHotkey": true,
            "enableCycleHotkey": true,
            "enableHideOthersHotkey": true,
            "hideKey": "-",
            "showSwitcher": true,
            "switcherDelay": 0.4,
        ])
        trigger = defaults.string(forKey: "trigger").flatMap(TriggerKey.init(rawValue:)) ?? .rightCommand
        paused = defaults.bool(forKey: "paused")
        assignments = defaults.data(forKey: "assignments")
            .flatMap { try? JSONDecoder().decode([String: StaticAssignment].self, from: $0) } ?? [:]
        ignoredKeys = defaults.data(forKey: "ignoredKeys")
            .flatMap { try? JSONDecoder().decode(Set<String>.self, from: $0) } ?? []
        ignoredApps = defaults.data(forKey: "ignoredApps")
            .flatMap { try? JSONDecoder().decode(Set<String>.self, from: $0) } ?? []
        dynamicFocusedAction = FocusedAction(rawValue: defaults.integer(forKey: "dynamicFocusedAction")) ?? .cycleApps
        enableAssignHotkey = defaults.bool(forKey: "enableAssignHotkey")
        enableCycleHotkey = defaults.bool(forKey: "enableCycleHotkey")
        enableHideOthersHotkey = defaults.bool(forKey: "enableHideOthersHotkey")
        alwaysHideOthers = defaults.bool(forKey: "alwaysHideOthers")
        activateAllWindows = defaults.bool(forKey: "activateAllWindows")
        excludeStaticFromCycle = defaults.bool(forKey: "excludeStaticFromCycle")
        hideKey = defaults.string(forKey: "hideKey") ?? "-"
        showSwitcher = defaults.bool(forKey: "showSwitcher")
        switcherDelay = defaults.double(forKey: "switcherDelay")
        switcherLayout = defaults.string(forKey: "switcherLayout").flatMap(SwitcherLayout.init(rawValue:)) ?? .compact
        hideMenuBarIcon = defaults.bool(forKey: "hideMenuBarIcon")
    }

    /// Assign `app` to `key`, taking the key away from any other app first.
    func assign(_ app: AppRef, to key: String, action: FocusedAction? = nil) {
        var table = assignments.filter { $0.value.bundleID != app.bundleID }
        table[key] = StaticAssignment(key: key, app: app,
                                      whenFocused: action ?? assignments[key]?.whenFocused ?? .cycleApps)
        assignments = table
    }

    func unassign(_ key: String) { assignments[key] = nil }

    func key(assignedTo bundleID: String) -> String? {
        assignments.values.first { $0.bundleID == bundleID }?.key
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Atajoly: login item change failed: \(error)")
        }
    }
}

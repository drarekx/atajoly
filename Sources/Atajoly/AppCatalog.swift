import AppKit
import Combine

/// An app as stored in assignments: enough to find, launch and draw it.
struct AppRef: Codable, Hashable {
    var bundleID: String
    var name: String
    var path: String

    init(bundleID: String, name: String, path: String) {
        self.bundleID = bundleID
        self.name = name
        self.path = path
    }

    init?(running app: NSRunningApplication) {
        guard let id = app.bundleIdentifier, let url = app.bundleURL else { return nil }
        self.init(bundleID: id, name: app.localizedName ?? url.deletingPathExtension().lastPathComponent, path: url.path)
    }

    init?(bundleURL url: URL) {
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
        self.init(bundleID: id, name: name.hasSuffix(".app") ? String(name.dropLast(4)) : name, path: url.path)
    }

    var url: URL { URL(fileURLWithPath: path) }

    /// Current location: the stored path, or wherever Launch Services finds the app now.
    var resolvedURL: URL? {
        if FileManager.default.fileExists(atPath: path) { return url }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    @MainActor var icon: NSImage { AppCatalog.icon(for: resolvedURL?.path ?? path) }
}

/// A key the user gave to one app by hand.
struct StaticAssignment: Codable, Hashable, Identifiable {
    var key: String
    var app: AppRef
    var whenFocused: FocusedAction
    var id: String { key }
    var bundleID: String { app.bundleID }
}

/// Keys Atajoly can use: letters and digits.
enum Keys {
    static let letters = "abcdefghijklmnopqrstuvwxyz".map(String.init)
    static let digits = "1234567890".map(String.init)
    static let all = letters + digits

    /// Vendor names skipped so "Google Chrome" lives on C, as in rcmd.
    private static let vendorPrefixes = ["Google ", "Microsoft "]

    /// The key an app gets automatically: the first letter or digit of its name,
    /// with accents folded ("Él" → "e").
    static func automaticKey(for name: String) -> String? {
        var name = name
        if let prefix = vendorPrefixes.first(where: { name.hasPrefix($0) && name.count > $0.count }) {
            name = String(name.dropFirst(prefix.count))
        }
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
        return folded.map(String.init).first { all.contains($0) }
    }
}

/// Running apps, how often each is used, and the apps installed on disk.
@MainActor
final class AppCatalog: ObservableObject {
    static let shared = AppCatalog()

    /// Regular (Dock) apps that are running, in launch order.
    @Published private(set) var running: [NSRunningApplication] = []
    /// Bundle ID → times it came to the front. Orders apps that share a letter.
    @Published private(set) var usage: [String: Int]
    @Published private(set) var installed: [AppRef] = []

    private var observers: [NSObjectProtocol] = []
    private var saveTask: DispatchWorkItem?
    private let defaults = UserDefaults.standard

    private init() {
        usage = defaults.dictionary(forKey: "usage") as? [String: Int] ?? [:]
    }

    func start() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                if let id = app?.bundleIdentifier { self?.countUse(id) }
            }
        })
        loadInstalled()
    }

    func refresh() {
        running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.bundleIdentifier != nil && $0.bundleURL != nil && !$0.isTerminated
        }
    }

    func runningApp(_ bundleID: String) -> NSRunningApplication? {
        running.first { $0.bundleIdentifier == bundleID }
    }

    func score(_ bundleID: String) -> Int { usage[bundleID] ?? 0 }

    private func countUse(_ bundleID: String) {
        usage[bundleID, default: 0] += 1
        saveTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.defaults.set(self.usage, forKey: "usage")
        }
        saveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: task)
    }

    // MARK: Keys

    /// Running apps that get `key` automatically, most used first.
    func automaticApps(for key: String) -> [NSRunningApplication] {
        let ignored = Settings.shared.ignoredApps
        return running
            .filter { app in
                guard let id = app.bundleIdentifier, !ignored.contains(id), id != Bundle.main.bundleIdentifier else { return false }
                return Keys.automaticKey(for: app.localizedName ?? "") == key
            }
            .sorted { score($0.bundleIdentifier!) > score($1.bundleIdentifier!) }
    }

    /// Everything `key` can reach, in cycling order: the hand-assigned app first,
    /// then running apps with that letter.
    func candidates(for key: String) -> [AppRef] {
        let settings = Settings.shared
        var list: [AppRef] = []
        let assigned = settings.assignments[key]
        if let assigned { list.append(assigned.app) }
        for app in automaticApps(for: key) {
            guard let ref = AppRef(running: app), !list.contains(where: { $0.bundleID == ref.bundleID }) else { continue }
            // An app assigned to another key keeps that key only.
            if let other = settings.key(assignedTo: ref.bundleID), other != key { continue }
            list.append(ref)
        }
        return list
    }

    // MARK: Installed apps

    /// Scans the usual app folders in the background (for the "choose app" menu).
    func loadInstalled() {
        Task.detached(priority: .utility) {
            let apps = AppCatalog.scanInstalled()
            await MainActor.run { AppCatalog.shared.installed = apps }
        }
    }

    nonisolated private static func scanInstalled() -> [AppRef] {
        let fm = FileManager.default
        let roots = ["/Applications", "/System/Applications", "/System/Applications/Utilities",
                     "/Applications/Utilities", NSHomeDirectory() + "/Applications"]
        var seen = Set<String>()
        var result: [AppRef] = []
        for root in roots {
            guard let items = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for item in items {
                let path = root + "/" + item
                if item.hasSuffix(".app") {
                    if let ref = AppRef(bundleURL: URL(fileURLWithPath: path)), seen.insert(ref.bundleID).inserted {
                        result.append(ref)
                    }
                } else if !item.hasPrefix("."), let inner = try? fm.contentsOfDirectory(atPath: path) {
                    // One level of folders (e.g. "Chrome Apps.localized").
                    for sub in inner where sub.hasSuffix(".app") {
                        if let ref = AppRef(bundleURL: URL(fileURLWithPath: path + "/" + sub)), seen.insert(ref.bundleID).inserted {
                            result.append(ref)
                        }
                    }
                }
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: Icons

    private static var iconCache: [String: NSImage] = [:]

    static func icon(for path: String) -> NSImage {
        if let cached = iconCache[path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        iconCache[path] = image
        return image
    }
}

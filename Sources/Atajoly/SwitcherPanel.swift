import AppKit
import SwiftUI

/// Floating overlay: the key map while the trigger is held, or a short
/// confirmation after assigning a key. Never takes focus.
@MainActor
final class SwitcherPanel {
    static let shared = SwitcherPanel()

    private var panel: NSPanel?
    private var hideTask: DispatchWorkItem?

    func show() {
        let entries = SwitcherEntry.current()
        guard !entries.isEmpty else { return }
        present(AnyView(SwitcherView(entries: entries, layout: Settings.shared.switcherLayout)))
    }

    func flash(key: String, app: AppRef, message: String) {
        present(AnyView(FlashView(key: key, app: app, message: message)))
        let task = DispatchWorkItem { [weak self] in self?.hide() }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: task)
    }

    func hide() {
        hideTask?.cancel()
        panel?.orderOut(nil)
    }

    private func present(_ view: AnyView) {
        hideTask?.cancel()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let hosting = NSHostingView(rootView: view
            .environment(\.colorScheme, .dark)
            .id(Localizer.shared.language))
        panel.contentView = hosting
        let size = hosting.fittingSize
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? .zero
        panel.setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                              width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        return panel
    }
}

/// One key in the overlay and the apps it reaches.
struct SwitcherEntry: Identifiable {
    let key: String
    let apps: [AppRef]
    let assigned: Bool
    let running: Bool
    var id: String { key }

    @MainActor
    static func current() -> [SwitcherEntry] {
        let catalog = AppCatalog.shared
        let settings = Settings.shared
        return Keys.all.compactMap { key in
            guard !settings.ignoredKeys.contains(key) else { return nil }
            let apps = catalog.candidates(for: key)
            guard let first = apps.first else { return nil }
            return SwitcherEntry(key: key, apps: apps, assigned: settings.assignments[key] != nil,
                                 running: catalog.runningApp(first.bundleID) != nil)
        }
    }
}

private struct SwitcherView: View {
    let entries: [SwitcherEntry]
    let layout: SwitcherLayout

    var body: some View {
        Group {
            switch layout {
            case .compact: compact
            case .comfortable: comfortable
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .background(Theme.window.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.lineStrong) }
        .foregroundStyle(Theme.text)
    }

    private var compact: some View {
        let columns = Array(repeating: GridItem(.fixed(64), spacing: 8), count: min(entries.count, 10))
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(entries) { entry in
                VStack(spacing: 4) {
                    Image(nsImage: entry.apps[0].icon)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .opacity(entry.running ? 1 : 0.55)
                    KeyCap(key: entry.key, assigned: entry.assigned, extra: entry.apps.count - 1)
                }
                .frame(width: 64)
            }
        }
    }

    private var comfortable: some View {
        let half = (entries.count + 1) / 2
        let columns = [Array(entries.prefix(half)), Array(entries.dropFirst(half))]
        return HStack(alignment: .top, spacing: 24) {
            ForEach(columns.indices, id: \.self) { column in
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(columns[column]) { entry in
                        HStack(spacing: 10) {
                            KeyCap(key: entry.key, assigned: entry.assigned, extra: 0)
                            Image(nsImage: entry.apps[0].icon).resizable().frame(width: 24, height: 24)
                            Text(entry.apps.map(\.name).joined(separator: " · "))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(entry.running ? Theme.text : Theme.text2)
                                .lineLimit(1)
                        }
                        .frame(width: 280, alignment: .leading)
                    }
                }
            }
        }
    }
}

/// Small key label. `assigned` keys (chosen by hand) use the accent colour.
struct KeyCap: View {
    let key: String
    var assigned = false
    var extra = 0

    var body: some View {
        HStack(spacing: 3) {
            Text(key.uppercased()).font(.system(size: 12, weight: .bold, design: .rounded))
            if extra > 0 {
                Text("+\(extra)").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.text3)
            }
        }
        .padding(.horizontal, 6)
        .frame(minWidth: 22, minHeight: 20)
        .background(assigned ? Theme.accentSoft : Theme.control, in: RoundedRectangle(cornerRadius: 5))
        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(assigned ? Theme.accentBorder : Theme.lineStrong) }
    }
}

private struct FlashView: View {
    let key: String
    let app: AppRef
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: app.icon).resizable().frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    KeyCap(key: key, assigned: true)
                    Text(app.name).font(.system(size: 14, weight: .semibold))
                }
                Text(message).font(.system(size: 12)).foregroundStyle(Theme.text2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .background(Theme.window.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.lineStrong) }
        .foregroundStyle(Theme.text)
    }
}

import AppKit
import SwiftUI

/// Floating overlay: the favorites and key map while the trigger is held, the chooser for a
/// letter shared by several apps, or a short confirmation after assigning a key.
/// Never takes focus, but the map and the chooser take clicks.
@MainActor
final class SwitcherPanel {
    static let shared = SwitcherPanel()

    private var panel: NSPanel?
    private var hideTask: DispatchWorkItem?

    /// Key map with the favorites on top. Clickable: a click opens that app.
    func show() {
        let settings = Settings.shared
        let entries = SwitcherEntry.current()
        let favorites = settings.showFavorites ? settings.favorites : []
        guard !entries.isEmpty || !favorites.isEmpty else { return }
        let view = SwitcherView(entries: entries, favorites: favorites, layout: settings.switcherLayout,
                                onOpen: { [weak self] app in
                                    self?.hide()
                                    Switcher.shared.open(app, hideOthers: settings.alwaysHideOthers)
                                },
                                onKey: { [weak self] key in
                                    self?.hide()
                                    Switcher.shared.focus(key: key, hideOthers: settings.alwaysHideOthers)
                                })
        present(AnyView(view), clickable: true)
    }

    /// The only view that takes clicks: picking an app with the mouse.
    func choose(_ model: ChooserModel) {
        present(AnyView(ChooserView(model: model)), clickable: true)
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

    private func present(_ view: AnyView, clickable: Bool = false) {
        hideTask?.cancel()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.ignoresMouseEvents = !clickable
        let hosting = FirstClickHostingView(rootView: view
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

/// Hosting view that acts on the first click, though the panel never becomes key.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Apps behind one letter and the one picked so far.
@MainActor
final class ChooserModel: ObservableObject {
    let key: String
    let apps: [AppRef]
    @Published var selection: Int
    /// Opens the app at that index (click, digit).
    var onPick: ((Int) -> Void)?

    init(key: String, apps: [AppRef], selection: Int) {
        self.key = key
        self.apps = apps
        self.selection = selection
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
    let favorites: [AppRef]
    let layout: SwitcherLayout
    let onOpen: (AppRef) -> Void
    let onKey: (String) -> Void

    var body: some View {
        VStack(spacing: 14) {
            if !favorites.isEmpty {
                favoritesRow
                if !entries.isEmpty { Rectangle().fill(Theme.lineStrong).frame(height: 1) }
            }
            if !entries.isEmpty {
                switch layout {
                case .compact: compact
                case .comfortable: comfortable
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .background(Theme.window.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.lineStrong) }
        .foregroundStyle(Theme.text)
    }

    /// Dock-like row: icon, name, and a dot under the apps that are running.
    private var favoritesRow: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(favorites, id: \.bundleID) { app in
                let running = AppCatalog.shared.runningApp(app.bundleID) != nil
                Button { onOpen(app) } label: {
                    VStack(spacing: 4) {
                        Image(nsImage: app.icon).resizable().frame(width: 48, height: 48)
                        Text(app.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.text2)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Circle().fill(running ? Theme.text2 : .clear).frame(width: 4, height: 4)
                    }
                    .frame(width: 64)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var compact: some View {
        let columns = Array(repeating: GridItem(.fixed(64), spacing: 8), count: min(entries.count, 10))
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(entries) { entry in
                Button { onKey(entry.key) } label: {
                    VStack(spacing: 4) {
                        Image(nsImage: entry.apps[0].icon)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .opacity(entry.running ? 1 : 0.55)
                        KeyCap(key: entry.key, assigned: entry.assigned, extra: entry.apps.count - 1)
                    }
                    .frame(width: 64)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
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
                        Button { onKey(entry.key) } label: {
                            HStack(spacing: 10) {
                                KeyCap(key: entry.key, assigned: entry.assigned, extra: 0)
                                Image(nsImage: entry.apps[0].icon).resizable().frame(width: 24, height: 24)
                                Text(entry.apps.map(\.name).joined(separator: " · "))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(entry.running ? Theme.text : Theme.text2)
                                    .lineLimit(1)
                            }
                            .frame(width: 280, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }
}

/// Plain button that dims while pressed (the overlay never becomes key, so no focus ring).
private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
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

/// Row of apps like ⌘⇥, numbered so 1–9 picks one directly.
private struct ChooserView: View {
    @ObservedObject var model: ChooserModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(model.apps.indices, id: \.self) { index in
                    let app = model.apps[index]
                    let selected = index == model.selection
                    VStack(spacing: 6) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .opacity(AppCatalog.shared.runningApp(app.bundleID) != nil ? 1 : 0.55)
                        KeyCap(key: index < 9 ? String(index + 1) : " ", assigned: selected)
                            .opacity(index < 9 ? 1 : 0)
                    }
                    .padding(10)
                    .background(selected ? Theme.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Theme.accentBorder : .clear)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { model.onPick?(index) }
                }
            }
            HStack(spacing: 8) {
                KeyCap(key: model.key)
                Text(model.apps[model.selection].name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
            }
            Text(tr("← → o la letra para moverte · 1–9 o ↩ para abrir · esc para cerrar"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.text3)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .background(Theme.window.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.lineStrong) }
        .foregroundStyle(Theme.text)
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

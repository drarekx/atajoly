import AppKit
import SwiftUI

/// Floating overlay: the favorites and key map while the trigger is held, the chooser for a
/// letter shared by several apps, or a short confirmation after assigning a key.
/// Never takes focus, but the map and the chooser take clicks.
///
/// It comes and goes through a short fog transition. The window is larger than the card by
/// `Fog.margin` on every side so the mist has room; the card stays centred where it always was.
@MainActor
final class SwitcherPanel {
    static let shared = SwitcherPanel()

    private var panel: NSPanel?
    private var hideTask: DispatchWorkItem?
    private let stage = FogStage()
    private let clock = FogClock()
    /// Where the overlay is heading: `true` from `present` until the next `hide`.
    /// The window itself stays on screen a little longer, until the dissolve ends.
    private var isShown = false
    private var clickable = false
    /// The card in screen coordinates; the rest of the window is transparent margin.
    private var cardFrame = NSRect.zero
    private var mouseMonitors: [Any] = []

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

    /// Dissolves the overlay. Safe to call when nothing is shown or while it is already leaving.
    func hide() {
        hideTask?.cancel()
        guard isShown, let panel else { return }
        isShown = false
        stopTrackingMouse()
        panel.ignoresMouseEvents = true
        let plain = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        clock.run(to: 0, duration: plain ? Fog.plainDisappear : Fog.disappear, plain: plain) { [weak self] in
            // Only reached when the dissolve ran to the end: a new `present` drops this completion.
            guard let self, !self.isShown else { return }
            self.panel?.orderOut(nil)
        }
    }

    private func present(_ view: AnyView, clickable: Bool = false) {
        hideTask?.cancel()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let content = AnyView(view
            .environment(\.colorScheme, Theme.isDark ? .dark : .light)
            .id(Localizer.shared.language)
            .environmentObject(clock))
        // Measured on a throwaway host: the live one may not have laid out the new content yet.
        let size = NSHostingView(rootView: content).fittingSize
        stage.content = content
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? .zero
        cardFrame = NSRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                           width: size.width, height: size.height)
        panel.setFrame(cardFrame.insetBy(dx: -Fog.margin, dy: -Fog.margin), display: true)
        self.clickable = clickable
        if clickable { startTrackingMouse() } else { stopTrackingMouse() }
        updateMousePassthrough()
        panel.orderFrontRegardless()
        // Already there (or on its way in): the content was swapped, nothing to replay.
        guard !isShown else { return }
        isShown = true
        // Starts from wherever the clock is: 0 when hidden, part-way when a dissolve was running.
        let plain = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        clock.run(to: 1, duration: plain ? Fog.plainAppear : Fog.appear, plain: plain)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The window shadow follows the window's shape, not the fading card: the card draws its own.
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.acceptsMouseMovedEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let hosting = FogHostingView(rootView: FogRoot(stage: stage, clock: clock))
        hosting.sizingOptions = []
        hosting.onMouse = { [weak self] in self?.updateMousePassthrough() }
        panel.contentView = hosting
        return panel
    }

    // MARK: Click-through margin

    /// The window takes clicks only while the pointer is over the card, so the transparent
    /// margin (and a dissolving or click-less overlay) never swallows a click meant for below.
    private func updateMousePassthrough() {
        guard let panel else { return }
        let ignores = !(clickable && isShown && cardFrame.contains(NSEvent.mouseLocation))
        if panel.ignoresMouseEvents != ignores { panel.ignoresMouseEvents = ignores }
    }

    private func startTrackingMouse() {
        guard mouseMonitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        let global = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateMousePassthrough() }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.updateMousePassthrough() }
            return event
        }
        mouseMonitors = [global, local].compactMap { $0 }
    }

    private func stopTrackingMouse() {
        mouseMonitors.forEach(NSEvent.removeMonitor)
        mouseMonitors = []
    }
}

// MARK: - Fog transition

private enum Fog {
    /// Transparent room around the card for the mist and the card's shadow.
    static let margin: CGFloat = 56
    static let appear = 0.22
    static let disappear = 0.18
    /// Reduce Motion: a plain quick fade.
    static let plainAppear = 0.10
    static let plainDisappear = 0.08

    /// Stable pseudo-random value in 0..<1, so the mist keeps its shape from frame to frame.
    static func noise(_ index: Int, _ salt: Int) -> Double {
        let value = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43758.5453
        return value - value.rounded(.down)
    }

    /// Point on the edge of `rect`, `fraction` (0..<1) of the way around it.
    static func point(on rect: CGRect, at fraction: Double) -> CGPoint {
        var distance = fraction * 2 * (rect.width + rect.height)
        if distance < rect.width { return CGPoint(x: rect.minX + distance, y: rect.minY) }
        distance -= rect.width
        if distance < rect.height { return CGPoint(x: rect.maxX, y: rect.minY + distance) }
        distance -= rect.height
        if distance < rect.width { return CGPoint(x: rect.maxX - distance, y: rect.maxY) }
        distance -= rect.width
        return CGPoint(x: rect.minX, y: rect.maxY - distance)
    }
}

/// What the overlay shows. Kept apart from the clock so a frame of the transition
/// does not rebuild the content.
@MainActor
private final class FogStage: ObservableObject {
    @Published var content = AnyView(EmptyView())
}

/// Timeline of the transition: 0 = gone (all drifted away), 1 = fully in view.
/// Driven by hand rather than by SwiftUI animations so that reversing half-way, and knowing
/// exactly when the dissolve has ended, are both trivial.
@MainActor
private final class FogClock: ObservableObject {
    @Published private(set) var progress = 0.0
    /// Reduce Motion: fade only, no mist, blur or scale.
    @Published private(set) var plain = false

    private var timer: Timer?
    private var completion: (() -> Void)?
    private var from = 0.0
    private var to = 0.0
    private var start: CFTimeInterval = 0
    private var duration = 0.0

    /// Moves from the current value to `target`. Replaces any run in flight, whose completion
    /// is dropped. `duration` is for the whole 0…1 range; a partial run takes its share.
    func run(to target: Double, duration full: Double, plain: Bool, completion: (() -> Void)? = nil) {
        timer?.invalidate()
        timer = nil
        if self.plain != plain { self.plain = plain }
        self.completion = completion
        from = progress
        to = target
        let distance = abs(to - from)
        guard distance > 0.001, full > 0 else { return finish() }
        duration = full * distance
        start = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let time = min(1, (CACurrentMediaTime() - start) / duration)
        // Ease-out when appearing, ease-in when dissolving.
        let eased = to > from ? 1 - pow(1 - time, 3) : time * time
        progress = from + (to - from) * eased
        if time >= 1 { finish() }
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        if progress != to { progress = to }
        let done = completion
        completion = nil
        done?()
    }
}

/// Mist behind and around the card, the card itself centred on top.
private struct FogRoot: View {
    @ObservedObject var stage: FogStage
    let clock: FogClock

    var body: some View {
        ZStack {
            Mist(clock: clock)
            stage.content.modifier(FogEmerge(clock: clock))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

/// The card as a whole: fades and settles into place.
private struct FogEmerge: ViewModifier {
    @ObservedObject var clock: FogClock

    func body(content: Content) -> some View {
        let progress = clock.progress
        content
            .opacity(clock.plain ? progress : min(1, progress * 1.4))
            .scaleEffect(clock.plain ? 1 : 0.975 + 0.025 * progress)
    }
}

/// Soft puffs along the card's edge. Densest early in the timeline and gone at both ends, and
/// further out the lower the progress: appearing, they gather inwards and clear; dissolving,
/// they rise as the card fades, drift outwards and thin out.
private struct Mist: View {
    @ObservedObject var clock: FogClock

    var body: some View {
        let progress = clock.progress
        if clock.plain || progress <= 0 || progress >= 1 {
            Color.clear
        } else {
            Canvas { context, size in
                let card = CGRect(origin: .zero, size: size).insetBy(dx: Fog.margin, dy: Fog.margin)
                guard card.width > 0, card.height > 0 else { return }
                let density = sin(.pi * pow(progress, 0.6))
                let away = 1 - progress
                let count = max(10, min(32, Int((card.width + card.height) / 28)))
                for index in 0..<count {
                    let a = Fog.noise(index, 1), b = Fog.noise(index, 2), c = Fog.noise(index, 3)
                    let edge = Fog.point(on: card, at: (Double(index) + a * 0.6) / Double(count))
                    let dx = edge.x - card.midX, dy = edge.y - card.midY
                    let length = max(1, hypot(dx, dy))
                    let drift = away * (6 + 10 * b)
                    let width = 36 + 24 * b, height = 26 + 16 * c
                    let puff = CGRect(x: edge.x + dx / length * drift - width / 2,
                                      y: edge.y + dy / length * drift - away * 4 * c - height / 2,
                                      width: width, height: height)
                    // Mostly the card's own substance, with a few wisps of the text colour so the
                    // mist shows against the desktop whether the palette is dark or light.
                    let wisp = index % 3 == 0
                    let tint = wisp ? Theme.text : Theme.window
                    let alpha = density * (wisp ? 0.14 + 0.10 * a : 0.38 + 0.22 * a)
                    context.fill(Path(ellipseIn: puff), with: .color(tint.opacity(alpha)))
                }
            }
            .blur(radius: 10)
            .allowsHitTesting(false)
        }
    }
}

/// Shared look of the overlay cards. The content inside sharpens as the fog clears; the
/// material behind it is left unfiltered and only fades with the card.
private struct FogCard: ViewModifier {
    let radius: CGFloat
    @EnvironmentObject private var clock: FogClock

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        content
            .blur(radius: clock.plain ? 0 : (1 - clock.progress) * 6)
            .background(.ultraThinMaterial, in: shape)
            .background(Theme.window.opacity(0.6), in: shape)
            .overlay { shape.strokeBorder(Theme.lineStrong) }
            .foregroundStyle(Theme.text)
            .background {
                // Stands in for the window shadow, which the oversized window no longer has.
                shape.fill(Color(nsColor: .shadowColor).opacity(0.3))
                    .blur(radius: 14)
                    .offset(y: 6)
            }
    }
}

/// Hosting view that acts on the first click, though the panel never becomes key, and reports
/// pointer movement over the window (the event monitors miss it in some activation states).
private final class FogHostingView: NSHostingView<FogRoot> {
    var onMouse: (() -> Void)?
    private var area: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                  owner: self)
        addTrackingArea(area)
        self.area = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onMouse?()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onMouse?()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onMouse?()
    }
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
        .modifier(FogCard(radius: 18))
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
        .modifier(FogCard(radius: 18))
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
        .modifier(FogCard(radius: 16))
    }
}

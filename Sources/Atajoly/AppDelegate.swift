import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var mainWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        Localizer.shared.$choice
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.setupMainMenu() }
            .store(in: &cancellables)
        AppCatalog.shared.start()
        Switcher.shared.start()
        setupStatusItem()
        Updater.shared.start()

        // First launch: show the window that explains how it works.
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "onboarded") {
            defaults.set(true, forKey: "onboarded")
            showMainWindow()
        }
    }

    /// Opening the app again (Finder, Spotlight) shows the window — the only way
    /// back in when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    // MARK: - Main menu

    /// Accessory apps show no menu bar, but text fields still need an Edit menu
    /// for ⌘C / ⌘V / ⌘X / ⌘A / ⌘Z to reach them.
    private func setupMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: tr("Cerrar ventana"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: tr("Salir de Atajoly"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: tr("Edición"))
        edit.addItem(withTitle: tr("Deshacer"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: tr("Rehacer"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: tr("Cortar"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: tr("Copiar"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: tr("Pegar"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: tr("Seleccionar todo"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        NSApp.mainMenu = main
    }

    // MARK: - Status bar menu

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "command", accessibilityDescription: "Atajoly")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        let settings = Settings.shared
        settings.$hideMenuBarIcon
            .receive(on: RunLoop.main)
            .sink { [weak self] hidden in self?.statusItem.isVisible = !hidden }
            .store(in: &cancellables)
        settings.$paused
            .receive(on: RunLoop.main)
            .sink { [weak self] paused in
                self?.statusItem.button?.appearsDisabled = paused
            }
            .store(in: &cancellables)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let settings = Settings.shared

        menu.addItem(withTitle: tr("Abrir Atajoly…"), action: #selector(showMainWindow), keyEquivalent: ",").target = self
        menu.addItem(.separator())

        let pause = menu.addItem(withTitle: tr("Pausar atajos"), action: #selector(togglePause), keyEquivalent: "p")
        pause.target = self
        pause.state = settings.paused ? .on : .off

        let login = menu.addItem(withTitle: tr("Abrir al iniciar sesión"), action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off

        menu.addItem(.separator())
        let updating = Updater.shared.state != .idle
        let update = menu.addItem(withTitle: updating ? tr("Actualizando…") : tr("Buscar actualizaciones…"),
                                  action: updating ? nil : #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        let coffee = menu.addItem(withTitle: tr("Invítame a un café…"), action: #selector(openBuyMeACoffee), keyEquivalent: "")
        coffee.target = self
        coffee.image = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: nil)
        let version = menu.addItem(withTitle: "Atajoly \(Updater.currentVersion)", action: nil, keyEquivalent: "")
        version.isEnabled = false
        menu.addItem(withTitle: tr("Salir de Atajoly"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc func showMainWindow() {
        if mainWindow == nil {
            // Wide enough for sidebar + full keyboard + key inspector, but never bigger than the screen.
            let visible = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
            let size = NSSize(width: min(1440, visible.width - 40), height: min(880, visible.height - 40))
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.title = "Atajoly"
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 1100, height: 640)
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = NSColor(red: 0x12 / 255, green: 0x12 / 255, blue: 0x14 / 255, alpha: 1)
            window.titlebarAppearsTransparent = true
            let hosting = NSHostingController(rootView: MainView())
            hosting.sizingOptions = []
            window.contentViewController = hosting
            window.setContentSize(size)
            window.center()
            mainWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openBuyMeACoffee() {
        NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/drarek")!)
    }

    @objc private func checkForUpdates() {
        Task { await Updater.shared.check(userInitiated: true) }
    }

    @objc private func togglePause() { Settings.shared.paused.toggle() }

    @objc private func toggleLogin() { LoginItem.setEnabled(!LoginItem.isEnabled) }
}

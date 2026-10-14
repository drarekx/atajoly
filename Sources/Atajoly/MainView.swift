import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum MainSection: Hashable {
    case keyboard, behaviour, settings
}

/// Main window: sidebar + the selected section, in Wallpy's dark style.
struct MainView: View {
    @State private var section: MainSection = .keyboard
    @ObservedObject private var localizer = Localizer.shared

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(section: $section)
            Rectangle().fill(Theme.line).frame(width: 1)
            Group {
                switch section {
                case .keyboard: KeyboardPane()
                case .behaviour: BehaviourPane()
                case .settings: SettingsPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .id(localizer.language)
        .background(Theme.window)
        .foregroundStyle(Theme.text)
        .font(.system(size: 13))
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .frame(minWidth: 1100, minHeight: 640)
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @Binding var section: MainSection
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var switcher = Switcher.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Theme.accentFill)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "command").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    }
                Text("Atajoly").font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 8)

            VStack(spacing: 2) {
                navItem(tr("Teclado"), "keyboard", .keyboard, count: settings.assignments.count)
                navItem(tr("Comportamiento"), "arrow.triangle.branch", .behaviour, count: nil)
                navItem(tr("Ajustes"), "slider.horizontal.3", .settings, count: nil)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(settings.paused ? Theme.warn : (switcher.triggerHeld ? Theme.accent : Theme.ok))
                        .frame(width: 8, height: 8)
                    Text(settings.paused ? tr("En pausa") : tr("Activo")).fontWeight(.medium)
                }
                Text(settings.paused
                     ? tr("Los atajos no hacen nada hasta que los reanudes.")
                     : tr("Mantén %@ y pulsa la inicial de una app.", settings.trigger.title))
                    .font(.system(size: 11)).foregroundStyle(Theme.text3)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    settings.paused.toggle()
                } label: {
                    Label(settings.paused ? tr("Reanudar atajos") : tr("Pausar atajos"),
                          systemImage: settings.paused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(AtajolyButtonStyle(kind: .secondary, height: 30, fullWidth: true))
            }
            .padding(12)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line) }

            Text(tr("Versión %@", Updater.currentVersion))
                .font(.system(size: 11)).foregroundStyle(Theme.text3)
                .padding(.horizontal, 10)
        }
        .padding(.horizontal, 12)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(width: 230)
        .frame(maxHeight: .infinity)
        .background(Theme.sidebar)
    }

    private func navItem(_ title: String, _ symbol: String, _ target: MainSection, count: Int?) -> some View {
        let selected = section == target
        return Button { section = target } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(selected ? Theme.accentText : Theme.text2)
                    .frame(width: 18)
                Text(title).fontWeight(selected ? .medium : .regular)
                Spacer()
                if let count, count > 0 {
                    Text("\(count)").font(.system(size: 11)).foregroundStyle(selected ? Color(hex: 0xA9B8DD) : Theme.text3)
                }
            }
            .foregroundStyle(selected ? .white : Color(hex: 0xC7C7CC))
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(selected ? Theme.navSelected : .clear, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Title bar of a pane.
private struct PaneHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title).font(.system(size: 20, weight: .semibold))
                if let subtitle {
                    Text(subtitle).foregroundStyle(Theme.text3)
                }
                Spacer()
                trailing
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }
}

extension PaneHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - Keyboard

private struct KeyboardPane: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var catalog = AppCatalog.shared
    @State private var selected: String? = "a"

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: tr("Teclado"),
                       subtitle: tr("%@ + letra abre la app; si ya está delante, hace su acción.", settings.trigger.title))
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        KeyboardMap(selected: $selected)
                            .atajolyCard(padding: 16)
                        legend
                        assignmentsCard
                        if !settings.ignoredApps.isEmpty { ignoredAppsCard }
                    }
                    .padding(24)
                    .frame(maxWidth: 900, alignment: .leading)
                }
                Rectangle().fill(Theme.line).frame(width: 1)
                KeyInspector(key: selected)
                    .frame(width: 320)
                    .background(Theme.sidebar)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 18) {
            legendItem(Theme.accentBorder, tr("Asignada a mano"))
            legendItem(Theme.lineStrong, tr("Apps abiertas"))
            legendItem(Theme.dangerBorder, tr("Desactivada"))
            Spacer()
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.text3)
    }

    private func legendItem(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).strokeBorder(color, lineWidth: 2).frame(width: 14, height: 14)
            Text(title)
        }
    }

    private var assignmentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tr("Asignadas a mano")).font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(tr("%@ + %@ + letra asigna la app activa", settings.trigger.symbol, Switcher.shared.assignModifierSymbol))
                    .font(.system(size: 11)).foregroundStyle(Theme.text3)
            }
            if settings.assignments.isEmpty {
                Text(tr("Ninguna todavía. Elige una tecla en el teclado y asígnale una app, aunque no esté abierta."))
                    .foregroundStyle(Theme.text3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(settings.assignments.values.sorted { $0.key < $1.key }) { assignment in
                    HStack(spacing: 10) {
                        KeyCap(key: assignment.key, assigned: true)
                        Image(nsImage: assignment.app.icon).resizable().frame(width: 22, height: 22)
                        Text(assignment.app.name).lineLimit(1)
                        Spacer()
                        FocusedActionPicker(selection: Binding(
                            get: { assignment.whenFocused },
                            set: { settings.assign(assignment.app, to: assignment.key, action: $0) }))
                            .frame(width: 280)
                        IconButton(symbol: "xmark", label: tr("Quitar")) { settings.unassign(assignment.key) }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atajolyCard()
    }

    private var ignoredAppsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Apps sin letra automática")).font(.system(size: 14, weight: .semibold))
            ForEach(settings.ignoredApps.sorted(), id: \.self) { id in
                HStack(spacing: 10) {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                        Image(nsImage: AppCatalog.icon(for: url.path)).resizable().frame(width: 22, height: 22)
                        Text(FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""))
                    } else {
                        Text(id).monospacedText()
                    }
                    Spacer()
                    Button(tr("Volver a incluir")) { settings.ignoredApps.remove(id) }
                        .buttonStyle(AtajolyButtonStyle(kind: .ghost, height: 26))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atajolyCard()
    }
}

/// The physical keyboard, labelled with the current layout, showing which app each key reaches.
private struct KeyboardMap: View {
    @Binding var selected: String?
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var catalog = AppCatalog.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(KeyboardLayout.rows.indices, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(KeyboardLayout.rows[row], id: \.self) { code in
                        let character = KeyboardLayout.character(for: code) ?? ""
                        keyView(character)
                    }
                }
                .padding(.leading, CGFloat(row) * 18)
            }
        }
    }

    @ViewBuilder
    private func keyView(_ character: String) -> some View {
        let usable = Keys.all.contains(character)
        let ignored = settings.ignoredKeys.contains(character)
        let assigned = settings.assignments[character] != nil
        let apps = usable && !ignored ? catalog.candidates(for: character) : []
        let isSelected = selected == character
        Button {
            if usable { selected = character }
        } label: {
            VStack(spacing: 3) {
                Group {
                    if let app = apps.first {
                        Image(nsImage: app.icon).resizable()
                            .opacity(catalog.runningApp(app.bundleID) != nil ? 1 : 0.5)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 30, height: 30)
                HStack(spacing: 2) {
                    Text(character.uppercased()).font(.system(size: 12, weight: .bold, design: .rounded))
                    if apps.count > 1 {
                        Text("+\(apps.count - 1)").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.text3)
                    }
                }
                .foregroundStyle(usable ? (ignored ? Theme.text3 : Theme.text) : Theme.text3.opacity(0.5))
                .strikethrough(ignored)
            }
            .frame(width: 62, height: 62)
            .background(isSelected ? Theme.navSelected : (usable ? Theme.control : Theme.field),
                        in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9).strokeBorder(
                    isSelected ? Theme.accent : (ignored ? Theme.dangerBorder : (assigned ? Theme.accentBorder : Theme.line)),
                    lineWidth: isSelected || assigned || ignored ? 2 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!usable)
        .help(apps.map(\.name).joined(separator: ", "))
    }
}

/// Right column: everything about one key.
private struct KeyInspector: View {
    let key: String?
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var catalog = AppCatalog.shared

    var body: some View {
        ScrollView {
            if let key {
                content(key)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(tr("Elige una tecla"))
                    .foregroundStyle(Theme.text3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
            }
        }
    }

    @ViewBuilder
    private func content(_ key: String) -> some View {
        let assignment = settings.assignments[key]
        let automatic = catalog.automaticApps(for: key)
            .compactMap(AppRef.init(running:))
            .filter { $0.bundleID != assignment?.bundleID }
        let ignored = Binding(
            get: { settings.ignoredKeys.contains(key) },
            set: { if $0 { settings.ignoredKeys.insert(key) } else { settings.ignoredKeys.remove(key) } })

        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Text(key.uppercased())
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .frame(width: 52, height: 52)
                    .background(Theme.control, in: RoundedRectangle(cornerRadius: 10))
                    .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.lineStrong) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Tecla %@", key.uppercased())).font(.system(size: 15, weight: .semibold))
                    Text("\(settings.trigger.symbol) + \(key.uppercased())").monospacedText().foregroundStyle(Theme.text3)
                }
            }

            SwitchRow(title: tr("Desactivar esta tecla"),
                      detail: tr("%@ + %@ vuelve a funcionar como siempre", settings.trigger.symbol, key.uppercased()),
                      isOn: ignored)

            if !ignored.wrappedValue {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(tr("App asignada"))
                    if let assignment {
                        HStack(spacing: 10) {
                            Image(nsImage: assignment.app.icon).resizable().frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(assignment.app.name).fontWeight(.medium).lineLimit(1)
                                Text(catalog.runningApp(assignment.bundleID) != nil ? tr("Abierta") : tr("Se abrirá al pulsar"))
                                    .font(.system(size: 11)).foregroundStyle(Theme.text3)
                            }
                            Spacer()
                            IconButton(symbol: "xmark", label: tr("Quitar")) { settings.unassign(key) }
                        }
                        Text(tr("Si ya está delante")).font(.system(size: 12)).foregroundStyle(Theme.text2)
                        FocusedActionPicker(selection: Binding(
                            get: { assignment.whenFocused },
                            set: { settings.assign(assignment.app, to: key, action: $0) }))
                    } else {
                        Text(tr("Ninguna: la tecla va a las apps abiertas que empiezan por %@.", key.uppercased()))
                            .font(.system(size: 12)).foregroundStyle(Theme.text3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    AppChooser(title: assignment == nil ? tr("Asignar app…") : tr("Cambiar app…")) { app in
                        settings.assign(app, to: key)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(tr("Apps abiertas con la %@", key.uppercased()))
                    if automatic.isEmpty {
                        Text(tr("Ninguna abierta ahora.")).font(.system(size: 12)).foregroundStyle(Theme.text3)
                    }
                    ForEach(automatic, id: \.bundleID) { app in
                        HStack(spacing: 10) {
                            Image(nsImage: app.icon).resizable().frame(width: 24, height: 24)
                            Text(app.name).lineLimit(1)
                            Spacer()
                            Menu {
                                Button(tr("Asignar a la %@", key.uppercased())) { settings.assign(app, to: key) }
                                Button(tr("No darle letra automática")) { settings.ignoredApps.insert(app.bundleID) }
                            } label: {
                                Image(systemName: "ellipsis")
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                        }
                    }
                    if automatic.count + (assignment == nil ? 0 : 1) > 1 {
                        Text(tr("Al pulsar la tecla otra vez se pasa a la siguiente."))
                            .font(.system(size: 11)).foregroundStyle(Theme.text3)
                    }
                }
            }
        }
    }
}

/// Menu with the installed apps, plus a file picker for anything else.
private struct AppChooser: View {
    let title: String
    let onChoose: (AppRef) -> Void
    @ObservedObject private var catalog = AppCatalog.shared

    var body: some View {
        Menu {
            let running = catalog.running.compactMap(AppRef.init(running:))
                .filter { $0.bundleID != Bundle.main.bundleIdentifier }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            Section(tr("Abiertas")) {
                ForEach(running, id: \.bundleID) { app in
                    Button { onChoose(app) } label: { Label { Text(app.name) } icon: { Image(nsImage: menuIcon(app)) } }
                }
            }
            Section(tr("Instaladas")) {
                ForEach(catalog.installed, id: \.bundleID) { app in
                    Button { onChoose(app) } label: { Label { Text(app.name) } icon: { Image(nsImage: menuIcon(app)) } }
                }
            }
            Divider()
            Button(tr("Otra app…")) { pickFile() }
        } label: {
            Label(title, systemImage: "plus")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Theme.control, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay { RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.lineStrong) }
    }

    private func menuIcon(_ app: AppRef) -> NSImage {
        let image = app.icon.copy() as! NSImage
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let app = AppRef(bundleURL: url) else { return }
        onChoose(app)
    }
}

private struct FocusedActionPicker: View {
    @Binding var selection: FocusedAction

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(FocusedAction.allCases) { action in
                Text(action.title).tag(action)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
    }
}

// MARK: - Behaviour

private struct BehaviourPane: View {
    @ObservedObject private var settings = Settings.shared
    @State private var trusted = Windows.isTrusted

    private let columns = [GridItem(.adaptive(minimum: 420), spacing: 20, alignment: .top)]

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: tr("Comportamiento"))
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    triggerCard
                    focusedCard
                    modifiersCard
                    switcherCard
                    chooserCard
                    hideCard
                    windowsCard
                }
                .padding(24)
                .frame(maxWidth: 1180)
            }
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            trusted = Windows.isTrusted
        }
    }

    private var triggerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Tecla de activación")).font(.system(size: 14, weight: .semibold))
            SegmentedControl(options: TriggerKey.allCases.map { ($0.title, $0) },
                             selection: $settings.trigger, expand: true)
            Text(tr("Solo la tecla derecha: la izquierda sigue haciendo los atajos de siempre."))
                .font(.system(size: 11)).foregroundStyle(Theme.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atajolyCard()
    }

    private var focusedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Si la app ya está delante")).font(.system(size: 14, weight: .semibold))
            FocusedActionPicker(selection: $settings.dynamicFocusedAction)
            Text(tr("Para las letras automáticas. Las asignadas a mano tienen su propia opción en Teclado."))
                .font(.system(size: 11)).foregroundStyle(Theme.text3)
                .fixedSize(horizontal: false, vertical: true)
            divider
            SwitchRow(title: tr("Traer todas las ventanas de la app"),
                      detail: tr("No solo la última que usaste"), isOn: $settings.activateAllWindows)
            divider
            SwitchRow(title: tr("Al pasar de app, saltar la asignada a mano"),
                      detail: tr("Recorre solo las apps abiertas con esa letra"), isOn: $settings.excludeStaticFromCycle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atajolyCard()
    }

    private var modifiersCard: some View {
        let trigger = settings.trigger.symbol
        return VStack(alignment: .leading, spacing: 0) {
            Text(tr("Teclas añadidas")).font(.system(size: 14, weight: .semibold)).padding(.bottom, 8)
            SwitchRow(title: tr("%@ + ⇧ izquierdo + letra: ocultar las demás", trigger),
                      detail: tr("Abre la app y oculta todas las otras"), isOn: $settings.enableHideOthersHotkey)
            divider
            SwitchRow(title: tr("Ocultar siempre las demás apps"),
                      detail: tr("Sin tener que añadir ⇧ izquierdo"), isOn: $settings.alwaysHideOthers)
            divider
            SwitchRow(title: tr("%@ + ⇧ derecho + letra: siguiente app", trigger),
                      detail: tr("Pasa a la siguiente app con la misma letra"), isOn: $settings.enableCycleHotkey)
            divider
            SwitchRow(title: tr("%@ + %@ + letra: asignar", trigger, Switcher.shared.assignModifierSymbol),
                      detail: tr("Da la letra a la app activa; otra vez la libera"), isOn: $settings.enableAssignHotkey)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atajolyCard()
    }

    private var switcherCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SwitchRow(title: tr("Mostrar el mapa de teclas"),
                      detail: tr("Al mantener la tecla de activación"), isOn: $settings.showSwitcher)
            if settings.showSwitcher {
                HStack {
                    Text(tr("Esperar")).foregroundStyle(Theme.text2)
                    Slider(value: $settings.switcherDelay, in: 0.1...1.5, step: 0.05)
                    Text(String(format: "%.2f s", settings.switcherDelay)).monospacedText().foregroundStyle(Theme.text2)
                        .frame(width: 56, alignment: .trailing)
                }
                SegmentedControl(options: SwitcherLayout.allCases.map { ($0.title, $0) },
                                 selection: $settings.switcherLayout, expand: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atajolyCard()
    }

    private var chooserCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SwitchRow(title: tr("Elegir app al mantener la letra"),
                      detail: tr("Si la letra tiene varias apps, muestra una lista para escoger con el teclado"),
                      isOn: $settings.showChooser)
            if settings.showChooser {
                HStack {
                    Text(tr("Esperar")).foregroundStyle(Theme.text2)
                    Slider(value: $settings.chooserDelay, in: 0.2...2, step: 0.05)
                    Text(String(format: "%.2f s", settings.chooserDelay)).monospacedText().foregroundStyle(Theme.text2)
                        .frame(width: 56, alignment: .trailing)
                }
                Text(tr("La lista se queda abierta: la letra o las flechas para moverte, 1–9, ↩ o un clic para abrir, esc para cerrar."))
                    .font(.system(size: 11)).foregroundStyle(Theme.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atajolyCard()
    }

    private var hideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Tecla para ocultar")).font(.system(size: 14, weight: .semibold))
            SegmentedControl(options: [("−", "-"), ("=", "="), (tr("Ninguna"), "")],
                             selection: $settings.hideKey, expand: true)
            Text(settings.hideKey.isEmpty
                 ? tr("Sin tecla para ocultar.")
                 : tr("%@ + %@ oculta la app activa; con ⇧, todas las demás.", settings.trigger.symbol, settings.hideKey))
                .font(.system(size: 11)).foregroundStyle(Theme.text3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atajolyCard()
    }

    private var windowsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(tr("Ventanas")).font(.system(size: 14, weight: .semibold))
                Spacer()
                Circle().fill(trusted ? Theme.ok : Theme.warn).frame(width: 8, height: 8)
                Text(trusted ? tr("Permiso concedido") : tr("Sin permiso")).font(.system(size: 12)).foregroundStyle(Theme.text2)
            }
            Text(tr("«Pasar a la siguiente ventana» necesita permiso de Accesibilidad. Lo demás funciona sin él."))
                .font(.system(size: 12)).foregroundStyle(Theme.text3)
                .fixedSize(horizontal: false, vertical: true)
            if !trusted {
                HStack {
                    Button(tr("Pedir permiso")) { Windows.requestAccess() }
                        .buttonStyle(.atajolyPrimary)
                    Button(tr("Abrir Ajustes del Sistema")) { Windows.openAccessibilitySettings() }
                        .buttonStyle(.atajolySecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atajolyCard()
    }

    private var divider: some View { Rectangle().fill(Theme.line).frame(height: 1) }
}

// MARK: - Settings

private struct SettingsPane: View {
    @ObservedObject private var localizer = Localizer.shared
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var updater = Updater.shared
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var autoUpdate = Updater.shared.autoCheck

    private let columns = [GridItem(.adaptive(minimum: 420), spacing: 20, alignment: .top)]

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: tr("Ajustes"))
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    languageCard
                    generalCard
                    updatesCard
                    helpCard
                }
                .padding(24)
                .frame(maxWidth: 1180)
            }
        }
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Idioma")).font(.system(size: 14, weight: .semibold))
            SegmentedControl(options: AppLanguage.allCases.map { ($0.nativeName, $0) },
                             selection: $localizer.choice, expand: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atajolyCard()
    }

    private var generalCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tr("General")).font(.system(size: 14, weight: .semibold)).padding(.bottom, 8)
            SwitchRow(title: tr("Abrir al iniciar sesión"), isOn: Binding(
                get: { launchAtLogin },
                set: { LoginItem.setEnabled($0); launchAtLogin = LoginItem.isEnabled }))
            Rectangle().fill(Theme.line).frame(height: 1)
            SwitchRow(title: tr("Ocultar el icono de la barra de menú"),
                      detail: tr("Para volver aquí, abre Atajoly otra vez desde Aplicaciones"),
                      isOn: $settings.hideMenuBarIcon)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atajolyCard()
    }

    private var updatesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Actualizaciones")).font(.system(size: 14, weight: .semibold))
            SwitchRow(title: tr("Buscar actualizaciones automáticamente"),
                      detail: tr("Al arrancar y una vez al día"),
                      isOn: Binding(get: { autoUpdate }, set: { updater.autoCheck = $0; autoUpdate = $0 }))
            HStack {
                Text(tr("Versión %@", Updater.currentVersion)).foregroundStyle(Theme.text2)
                Spacer()
                Button(updater.state == .idle ? tr("Buscar ahora") : tr("Actualizando…")) {
                    Task { await updater.check(userInitiated: true) }
                }
                .buttonStyle(.atajolySecondary)
                .disabled(updater.state != .idle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atajolyCard()
    }

    private var helpCard: some View {
        let t = settings.trigger.symbol
        let rows: [(String, String)] = [
            ("\(t) + A", tr("Abre la app que empieza por A, o la asignada a la A")),
            ("\(t) + A", tr("Otra vez: su acción (ocultar, siguiente app…)")),
            ("\(t) ⇧ + A", tr("⇧ izquierdo: abre y oculta las demás · ⇧ derecho: siguiente app")),
            ("\(t) \(Switcher.shared.assignModifierSymbol) + A", tr("Asigna la A a la app activa")),
            ("\(t) + −", tr("Oculta la app activa")),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            Text(tr("Cómo se usa")).font(.system(size: 14, weight: .semibold))
            ForEach(rows.indices, id: \.self) { index in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(rows[index].0).monospacedText().foregroundStyle(Theme.accentText).frame(width: 80, alignment: .leading)
                    Text(rows[index].1).foregroundStyle(Theme.text2).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atajolyCard()
    }
}

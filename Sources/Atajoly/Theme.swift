import SwiftUI

/// One colour per role of the interface. `Theme` hands out the current one.
struct ThemePalette {
    /// Dark palettes get dark native controls (switches, text fields, scrollers); light ones, light.
    let isDark: Bool

    let window: Color
    let editorBackground: Color
    let sidebar: Color
    let card: Color
    let field: Color
    let control: Color
    let line: Color
    let lineStrong: Color
    /// Selected pill of a segmented control.
    let segmentSelected: Color

    let text: Color
    let text2: Color
    let text3: Color
    /// Sidebar items: idle, selected, and the counter of the selected one.
    let navText: Color
    let navSelectedText: Color
    let navSelectedCount: Color

    let accent: Color
    let accentText: Color
    let accentFill: Color
    /// Text and symbols drawn on top of `accentFill`.
    let onAccent: Color
    let accentSoft: Color
    let accentBorder: Color
    let navSelected: Color

    let playhead: Color
    let ok: Color
    let warn: Color
    let danger: Color
    let dangerBorder: Color
}

extension ThemePalette {
    /// Builds a palette from the published colours of a scheme. The roles a scheme does not
    /// define (hairlines, soft accent fills, pressed states) are blends of the ones it does.
    /// Where a published colour is too faint for its role (Nord's red or Dracula's comment grey
    /// as text), the palette passes it blended towards its own text colour.
    init(isDark: Bool, sunken: UInt32, window: UInt32, sidebar: UInt32? = nil, card: UInt32,
         field: UInt32? = nil, control: UInt32? = nil, line: UInt32? = nil, lineStrong: UInt32? = nil,
         text: UInt32, text2: UInt32, text3: UInt32,
         accent: UInt32, accentText: UInt32? = nil, accentFill: UInt32? = nil, onAccent: UInt32,
         ok: UInt32, warn: UInt32, danger: UInt32, playhead: UInt32? = nil) {
        let mix = ThemePalette.mix
        let sidebar = sidebar ?? mix(window, card, 0.6)
        let control = control ?? mix(card, text, 0.10)
        let lineStrong = lineStrong ?? mix(card, text, 0.24)
        let accentText = accentText ?? accent

        self.isDark = isDark
        self.window = Color(hex: window)
        self.editorBackground = Color(hex: sunken)
        self.sidebar = Color(hex: sidebar)
        self.card = Color(hex: card)
        self.field = Color(hex: field ?? mix(card, text, 0.05))
        self.control = Color(hex: control)
        self.line = Color(hex: line ?? mix(card, text, 0.12))
        self.lineStrong = Color(hex: lineStrong)
        self.segmentSelected = Color(hex: mix(control, lineStrong, 0.7))
        self.text = Color(hex: text)
        self.text2 = Color(hex: text2)
        self.text3 = Color(hex: text3)
        self.navText = Color(hex: mix(text, text2, 0.5))
        self.navSelectedText = Color(hex: text)
        self.navSelectedCount = Color(hex: mix(accentText, text, 0.5))
        self.accent = Color(hex: accent)
        self.accentText = Color(hex: accentText)
        self.accentFill = Color(hex: accentFill ?? accent)
        self.onAccent = Color(hex: onAccent)
        self.accentSoft = Color(hex: mix(card, accent, 0.18))
        self.accentBorder = Color(hex: mix(card, accent, 0.55))
        self.navSelected = Color(hex: mix(sidebar, accent, 0.20))
        self.playhead = Color(hex: playhead ?? danger)
        self.ok = Color(hex: ok)
        self.warn = Color(hex: warn)
        self.danger = Color(hex: danger)
        self.dangerBorder = Color(hex: mix(card, danger, 0.28))
    }

    /// `a` moved `amount` (0…1) of the way to `b`, per sRGB channel.
    static func mix(_ a: UInt32, _ b: UInt32, _ amount: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let from = Double((a >> shift) & 0xFF), to = Double((b >> shift) & 0xFF)
            return UInt32((from + (to - from) * amount).rounded()) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }

    /// Atajoly's own dark look (same family as Wallpy).
    static let atajoly = ThemePalette(
        isDark: true,
        window: Color(hex: 0x121214),
        editorBackground: Color(hex: 0x0E0E10),
        sidebar: Color(hex: 0x18181A),
        card: Color(hex: 0x1A1A1D),
        field: Color(hex: 0x202023),
        control: Color(hex: 0x26262A),
        line: Color(hex: 0x2A2A2E),
        lineStrong: Color(hex: 0x3A3A3F),
        segmentSelected: Color(hex: 0x34343A),
        text: Color(hex: 0xECECEE),
        text2: Color(hex: 0xA1A1A6),
        text3: Color(hex: 0x8A8A90),
        navText: Color(hex: 0xC7C7CC),
        navSelectedText: Color(hex: 0xFFFFFF),
        navSelectedCount: Color(hex: 0xA9B8DD),
        accent: Color(hex: 0x5C8CFF),
        accentText: Color(hex: 0x7AA2FF),
        accentFill: Color(hex: 0x3566E0),
        onAccent: Color(hex: 0xFFFFFF),
        accentSoft: Color(hex: 0x22304F),
        accentBorder: Color(hex: 0x3D5BB0),
        navSelected: Color(hex: 0x26304A),
        playhead: Color(hex: 0xFF4D4D),
        ok: Color(hex: 0x3CCF7A),
        warn: Color(hex: 0xF5C46B),
        danger: Color(hex: 0xFF7B7B),
        dangerBorder: Color(hex: 0x4A2A2C))

    /// Solarized (Ethan Schoonover): base03/base02 surfaces, base2…base0 text, blue accent.
    static let solarizedDark = ThemePalette(
        isDark: true, sunken: 0x00212B, window: 0x002B36, card: 0x073642, field: 0x002B36,
        text: 0xEEE8D5, text2: 0x93A1A1, text3: 0x839496,
        accent: 0x268BD2, accentText: mix(0x268BD2, 0xEEE8D5, 0.3), accentFill: mix(0x268BD2, 0x002B36, 0.25),
        onAccent: 0xFDF6E3,
        ok: 0x859900, warn: 0xB58900, danger: mix(0xDC322F, 0xEEE8D5, 0.2), playhead: 0xD33682)

    /// Solarized light: base2/base3 surfaces, base02…base00 text, blue accent.
    static let solarizedLight = ThemePalette(
        isDark: false, sunken: 0xE4DDC8, window: 0xEEE8D5, card: 0xFDF6E3,
        text: 0x073642, text2: mix(0x586E75, 0x073642, 0.2), text3: 0x657B83,
        accent: 0x268BD2, accentText: mix(0x268BD2, 0x073642, 0.3), accentFill: mix(0x268BD2, 0x002B36, 0.25),
        onAccent: 0xFDF6E3,
        ok: mix(0x859900, 0x073642, 0.2), warn: mix(0xB58900, 0x073642, 0.2), danger: 0xDC322F, playhead: 0xD33682)

    /// Dracula: background, current line, foreground, comment, purple accent.
    static let dracula = ThemePalette(
        isDark: true, sunken: 0x191A21, window: 0x21222C, card: 0x282A36,
        lineStrong: 0x44475A,
        text: 0xF8F8F2, text2: 0xBFC2D6, text3: mix(0x6272A4, 0xF8F8F2, 0.2),
        accent: 0xBD93F9, onAccent: 0x282A36,
        ok: 0x50FA7B, warn: 0xFFB86C, danger: 0xFF5555, playhead: 0xFF79C6)

    /// Nord: polar night surfaces (nord0–nord3), snow storm text, frost accent (nord8).
    static let nord = ThemePalette(
        isDark: true, sunken: 0x272C36, window: 0x2E3440, card: 0x3B4252,
        control: 0x434C5E, lineStrong: 0x4C566A,
        text: 0xECEFF4, text2: 0xD8DEE9, text3: 0xA3ABBA,
        accent: 0x88C0D0, onAccent: 0x2E3440,
        ok: 0xA3BE8C, warn: 0xEBCB8B, danger: mix(0xBF616A, 0xECEFF4, 0.25))

    /// Gruvbox dark: bg0_h…bg3 surfaces, fg1/fg3/fg4 text, bright blue accent.
    static let gruvboxDark = ThemePalette(
        isDark: true, sunken: 0x1D2021, window: 0x282828, sidebar: 0x32302F, card: 0x3C3836,
        control: 0x504945, lineStrong: 0x665C54,
        text: 0xEBDBB2, text2: 0xBDAE93, text3: 0xA89984,
        accent: 0x83A598, onAccent: 0x282828,
        ok: 0xB8BB26, warn: 0xFABD2F, danger: 0xFB4934)

    /// Catppuccin Mocha: crust/mantle/base/surface0–2, text/subtext0/overlay2, mauve accent.
    static let catppuccinMocha = ThemePalette(
        isDark: true, sunken: 0x11111B, window: 0x1E1E2E, sidebar: 0x181825, card: 0x313244,
        control: 0x45475A, lineStrong: 0x585B70,
        text: 0xCDD6F4, text2: 0xA6ADC8, text3: 0x9399B2,
        accent: 0xCBA6F7, onAccent: 0x1E1E2E,
        ok: 0xA6E3A1, warn: 0xF9E2AF, danger: 0xF38BA8)

    /// Tokyo Night: bg_dark/bg/storm bg/bg_highlight, fg/fg_dark/dark5, blue accent.
    static let tokyoNight = ThemePalette(
        isDark: true, sunken: 0x16161E, window: 0x1A1B26, card: 0x24283B,
        control: 0x292E42, lineStrong: 0x3B4261,
        text: 0xC0CAF5, text2: 0xA9B1D6, text3: 0x737AA2,
        accent: 0x7AA2F7, onAccent: 0x1A1B26,
        ok: 0x9ECE6A, warn: 0xE0AF68, danger: 0xF7768E)

    /// One Dark (Atom): UI and editor backgrounds, gutter, foreground, blue accent.
    static let oneDark = ThemePalette(
        isDark: true, sunken: 0x181A1F, window: 0x21252B, card: 0x282C34,
        field: 0x2C313A, lineStrong: 0x3E4451,
        text: 0xABB2BF, text2: 0x9DA5B4, text3: 0x7F848E,
        accent: 0x61AFEF, onAccent: 0x21252B,
        ok: 0x98C379, warn: 0xE5C07B, danger: 0xE06C75)

    /// Monokai: background, line highlight, selection, foreground, blue accent.
    static let monokai = ThemePalette(
        isDark: true, sunken: 0x171813, window: 0x1E1F1C, card: 0x272822,
        control: 0x3E3D32, lineStrong: 0x49483E,
        text: 0xF8F8F2, text2: 0xCFCFC2, text3: mix(0x75715E, 0xF8F8F2, 0.2),
        accent: 0x66D9EF, onAccent: 0x272822,
        ok: 0xA6E22E, warn: 0xE6DB74, danger: 0xF92672)
}

/// Colour themes the user can pick. Raw values are stored in the preferences: never rename them.
enum ThemeID: String, CaseIterable, Identifiable {
    case atajoly, solarizedDark, solarizedLight, dracula, nord, gruvboxDark, catppuccinMocha, tokyoNight, oneDark, monokai
    var id: String { rawValue }

    /// Proper noun, the same in every language.
    var name: String {
        switch self {
        case .atajoly: return "Atajoly"
        case .solarizedDark: return "Solarized Dark"
        case .solarizedLight: return "Solarized Light"
        case .dracula: return "Dracula"
        case .nord: return "Nord"
        case .gruvboxDark: return "Gruvbox Dark"
        case .catppuccinMocha: return "Catppuccin Mocha"
        case .tokyoNight: return "Tokyo Night"
        case .oneDark: return "One Dark"
        case .monokai: return "Monokai"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .atajoly: return .atajoly
        case .solarizedDark: return .solarizedDark
        case .solarizedLight: return .solarizedLight
        case .dracula: return .dracula
        case .nord: return .nord
        case .gruvboxDark: return .gruvboxDark
        case .catppuccinMocha: return .catppuccinMocha
        case .tokyoNight: return .tokyoNight
        case .oneDark: return .oneDark
        case .monokai: return .monokai
        }
    }
}

/// Colours of the interface, read from the current palette.
enum Theme {
    /// Palette in use. `Settings` sets it at launch and whenever the user picks another theme.
    private(set) static var palette = ThemePalette.atajoly

    static func apply(_ theme: ThemeID) { palette = theme.palette }

    static var isDark: Bool { palette.isDark }

    static var window: Color { palette.window }
    static var editorBackground: Color { palette.editorBackground }
    static var sidebar: Color { palette.sidebar }
    static var card: Color { palette.card }
    static var field: Color { palette.field }
    static var control: Color { palette.control }
    static var line: Color { palette.line }
    static var lineStrong: Color { palette.lineStrong }
    static var segmentSelected: Color { palette.segmentSelected }

    static var text: Color { palette.text }
    static var text2: Color { palette.text2 }
    static var text3: Color { palette.text3 }
    static var navText: Color { palette.navText }
    static var navSelectedText: Color { palette.navSelectedText }
    static var navSelectedCount: Color { palette.navSelectedCount }

    static var accent: Color { palette.accent }
    static var accentText: Color { palette.accentText }
    static var accentFill: Color { palette.accentFill }
    static var onAccent: Color { palette.onAccent }
    static var accentSoft: Color { palette.accentSoft }
    static var accentBorder: Color { palette.accentBorder }
    static var navSelected: Color { palette.navSelected }

    static var playhead: Color { palette.playhead }
    static var ok: Color { palette.ok }
    static var warn: Color { palette.warn }
    static var danger: Color { palette.danger }
    static var dangerBorder: Color { palette.dangerBorder }

    static let radius: CGFloat = 8
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - Buttons

struct AtajolyButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, ghost, danger }
    var kind: Kind = .secondary
    var height: CGFloat = 32
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration, kind: kind, height: height, fullWidth: fullWidth)
    }

    private struct StyledButton: View {
        let configuration: Configuration
        let kind: Kind
        let height: CGFloat
        let fullWidth: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: kind == .primary ? .semibold : .regular))
                .foregroundStyle(foreground)
                .padding(.horizontal, 14)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(height: height)
                .background(background, in: RoundedRectangle(cornerRadius: Theme.radius))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(border, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: Theme.radius))
                .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
        }

        private var foreground: Color {
            switch kind {
            case .primary: return Theme.onAccent
            case .danger: return Theme.danger
            case .ghost: return Theme.text2
            case .secondary: return Theme.text
            }
        }

        private var background: Color {
            switch kind {
            case .primary: return Theme.accentFill
            case .secondary: return Theme.control
            case .ghost, .danger: return .clear
            }
        }

        private var border: Color {
            switch kind {
            case .primary: return .clear
            case .secondary: return Theme.lineStrong
            case .ghost: return Theme.line
            case .danger: return Theme.dangerBorder
            }
        }
    }
}

extension ButtonStyle where Self == AtajolyButtonStyle {
    static var atajolyPrimary: AtajolyButtonStyle { AtajolyButtonStyle(kind: .primary) }
    static var atajolySecondary: AtajolyButtonStyle { AtajolyButtonStyle(kind: .secondary) }
    static var atajolyGhost: AtajolyButtonStyle { AtajolyButtonStyle(kind: .ghost) }
    static var atajolyDanger: AtajolyButtonStyle { AtajolyButtonStyle(kind: .danger) }
}

/// Square icon-only button.
struct IconButton: View {
    let symbol: String
    let label: String
    var kind: AtajolyButtonStyle.Kind = .ghost
    var size: CGFloat = 32
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .medium))
        }
        .buttonStyle(AtajolyButtonStyle(kind: kind, height: size))
        .frame(width: size)
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Controls

/// Pill segmented control in the app's style.
struct SegmentedControl<Value: Hashable>: View {
    let options: [(String, Value)]
    @Binding var selection: Value
    var expand = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let (title, value) = options[index]
                let selected = value == selection
                Button { selection = value } label: {
                    Text(title)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Theme.text : Theme.text2)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: expand ? .infinity : nil)
                        .frame(height: 26)
                        .background(selected ? Theme.segmentSelected : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay { RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.line) }
    }
}

/// Small uppercase heading used above groups.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Theme.text3)
    }
}

/// Text field with the app's field look.
struct AtajolyTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String?
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon).font(.system(size: 12)).foregroundStyle(Theme.text3)
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .onSubmit(onSubmit)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay { RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.lineStrong) }
    }
}

/// A labelled switch row.
struct SwitchRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Theme.text)
                if let detail {
                    Text(detail).font(.system(size: 11)).foregroundStyle(Theme.text3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .tint(Theme.accentFill)
        .controlSize(.small)
        .padding(.vertical, 8)
    }
}

extension View {
    /// Rounded card surface.
    func atajolyCard(padding: CGFloat = 20) -> some View {
        self.padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line) }
    }

    func monospacedText(size: CGFloat = 12) -> some View {
        self.font(.system(size: size, design: .monospaced))
    }
}


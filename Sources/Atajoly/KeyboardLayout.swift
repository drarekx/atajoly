import Carbon

/// Maps characters to virtual key codes for the current keyboard layout, so
/// shortcuts follow the letter printed on the key (AZERTY, Dvorak…).
enum KeyboardLayout {
    /// Physical rows of the ANSI keyboard (number row to bottom row), as key codes.
    static let rows: [[UInt32]] = [
        [18, 19, 20, 21, 23, 22, 26, 28, 25, 29],
        [12, 13, 14, 15, 17, 16, 32, 34, 31, 35],
        [0, 1, 2, 3, 5, 4, 38, 40, 37, 41],
        [6, 7, 8, 9, 11, 45, 46, 43, 47, 44],
    ]

    /// US ANSI fallback when the layout can't be read.
    private static let ansi: [UInt32: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
        11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 31: "o", 32: "u", 34: "i", 35: "p", 37: "l", 38: "j", 40: "k", 45: "n",
        46: "m", 41: ";", 43: ",", 44: "/", 47: ".",
    ]

    private static var cache: [UInt32: String]?

    /// Key code → lowercase character it types with no modifiers.
    static var characters: [UInt32: String] {
        if let cache { return cache }
        let table = readLayout() ?? ansi
        cache = table
        return table
    }

    /// Character → key code. Digits fall back to the number row, which on
    /// AZERTY types symbols without ⇧.
    static func keyCode(for character: String) -> UInt32? {
        characters.first { $0.value == character }?.key
            ?? (Keys.digits.contains(character) ? ansi.first { $0.value == character }?.key : nil)
    }

    static func character(for keyCode: UInt32) -> String? { characters[keyCode] }

    /// Call when the input source changes.
    static func reset() { cache = nil }

    private static func readLayout() -> [UInt32: String]? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
            ?? TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
            let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var table: [UInt32: String] = [:]
        data.withUnsafeBytes { raw in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return }
            for code in UInt16(0)..<UInt16(64) {
                var deadKeys: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                            OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, 4, &length, &chars)
                guard status == noErr, length > 0 else { continue }
                let string = String(utf16CodeUnits: chars, count: length).lowercased()
                if !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    table[UInt32(code)] = string
                }
            }
        }
        return table.isEmpty ? nil : table
    }
}

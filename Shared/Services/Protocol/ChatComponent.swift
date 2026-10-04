//
//  ChatComponent.swift
//  MinecraftServerViewer
//
//  Decodes Java Edition JSON text components (the status `description`)
//  and flattens them into legacy `§` codes so MOTDFormatter can render them.
//

import Foundation

nonisolated struct ChatComponent: Decodable {
    var text = ""
    var color: String?
    var bold: Bool?
    var italic: Bool?
    var underlined: Bool?
    var strikethrough: Bool?
    var obfuscated: Bool?
    var extra: [ChatComponent] = []

    private enum CodingKeys: String, CodingKey {
        case text, translate, color, bold, italic, underlined, strikethrough, obfuscated, extra
    }

    init(from decoder: Decoder) throws {
        // A component may be a bare string, an array (first element is the
        // parent of the rest), or an object.
        if let single = try? decoder.singleValueContainer() {
            if let string = try? single.decode(String.self) {
                text = string
                return
            }
            if var array = try? single.decode([ChatComponent].self), !array.isEmpty {
                self = array.removeFirst()
                extra += array
                return
            }
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = (try? container.decodeIfPresent(String.self, forKey: .text))
            ?? (try? container.decodeIfPresent(String.self, forKey: .translate))
            ?? ""
        color = try? container.decodeIfPresent(String.self, forKey: .color)
        bold = try? container.decodeIfPresent(Bool.self, forKey: .bold)
        italic = try? container.decodeIfPresent(Bool.self, forKey: .italic)
        underlined = try? container.decodeIfPresent(Bool.self, forKey: .underlined)
        strikethrough = try? container.decodeIfPresent(Bool.self, forKey: .strikethrough)
        obfuscated = try? container.decodeIfPresent(Bool.self, forKey: .obfuscated)
        extra = (try? container.decodeIfPresent([ChatComponent].self, forKey: .extra)) ?? []
    }

    /// The component tree as a string with legacy `§` formatting codes.
    var legacyText: String {
        var output = ""
        var emitted = Style()
        append(to: &output, inherited: Style(), emitted: &emitted)
        return output
    }

    private func append(to output: inout String, inherited: Style, emitted: inout Style) {
        let style = inherited.applying(self)
        if !text.isEmpty {
            if style != emitted {
                output += style.codes
                emitted = style
            }
            output += text
        }
        for child in extra {
            child.append(to: &output, inherited: style, emitted: &emitted)
        }
    }

    private struct Style: Equatable {
        var color: Character?
        var bold = false, italic = false, underlined = false, strikethrough = false, obfuscated = false

        func applying(_ component: ChatComponent) -> Style {
            var style = self
            if let color = component.color.flatMap(LegacyColor.code(for:)) { style.color = color }
            style.bold = component.bold ?? bold
            style.italic = component.italic ?? italic
            style.underlined = component.underlined ?? underlined
            style.strikethrough = component.strikethrough ?? strikethrough
            style.obfuscated = component.obfuscated ?? obfuscated
            return style
        }

        /// Reset, then color (which also clears formatting in-game), then formats.
        var codes: String {
            var codes = "§r"
            if let color { codes += "§\(color)" }
            if obfuscated { codes += "§k" }
            if bold { codes += "§l" }
            if strikethrough { codes += "§m" }
            if underlined { codes += "§n" }
            if italic { codes += "§o" }
            return codes
        }
    }
}

nonisolated enum LegacyColor {
    private static let named: [String: Character] = [
        "black": "0", "dark_blue": "1", "dark_green": "2", "dark_aqua": "3",
        "dark_red": "4", "dark_purple": "5", "gold": "6", "gray": "7",
        "dark_gray": "8", "blue": "9", "green": "a", "aqua": "b",
        "red": "c", "light_purple": "d", "yellow": "e", "white": "f",
    ]

    private static let palette: [(code: Character, rgb: Int)] = [
        ("0", 0x000000), ("1", 0x0000AA), ("2", 0x00AA00), ("3", 0x00AAAA),
        ("4", 0xAA0000), ("5", 0xAA00AA), ("6", 0xFFAA00), ("7", 0xAAAAAA),
        ("8", 0x555555), ("9", 0x5555FF), ("a", 0x55FF55), ("b", 0x55FFFF),
        ("c", 0xFF5555), ("d", 0xFF55FF), ("e", 0xFFFF55), ("f", 0xFFFFFF),
    ]

    /// Maps a named color, or a `#RRGGBB` color to its nearest legacy color.
    static func code(for color: String) -> Character? {
        if let code = named[color] { return code }
        guard color.hasPrefix("#"), let rgb = Int(color.dropFirst(), radix: 16) else { return nil }
        func distance(_ other: Int) -> Int {
            let dr = (rgb >> 16 & 0xFF) - (other >> 16 & 0xFF)
            let dg = (rgb >> 8 & 0xFF) - (other >> 8 & 0xFF)
            let db = (rgb & 0xFF) - (other & 0xFF)
            return dr * dr + dg * dg + db * db
        }
        return palette.min { distance($0.rgb) < distance($1.rgb) }?.code
    }
}

nonisolated extension String {
    /// Removes `§x` formatting codes, for fields shown as plain text.
    var strippingFormattingCodes: String {
        var result = ""
        var iterator = makeIterator()
        while let character = iterator.next() {
            if character == "§" {
                _ = iterator.next()
            } else {
                result.append(character)
            }
        }
        return result
    }
}

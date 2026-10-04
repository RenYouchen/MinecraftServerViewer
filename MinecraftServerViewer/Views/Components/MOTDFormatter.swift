//
//  MOTDFormatter.swift
//  MinecraftServerViewer
//
//  Converts legacy `§` formatting codes into an AttributedString.
//

import SwiftUI

enum MOTDFormatter {
    static let defaultColor = Color(hex: 0xAAAAAA)

    static let colors: [Character: Color] = [
        "0": Color(hex: 0x000000), "1": Color(hex: 0x0000AA), "2": Color(hex: 0x00AA00), "3": Color(hex: 0x00AAAA),
        "4": Color(hex: 0xAA0000), "5": Color(hex: 0xAA00AA), "6": Color(hex: 0xFFAA00), "7": Color(hex: 0xAAAAAA),
        "8": Color(hex: 0x555555), "9": Color(hex: 0x5555FF), "a": Color(hex: 0x55FF55), "b": Color(hex: 0x55FFFF),
        "c": Color(hex: 0xFF5555), "d": Color(hex: 0xFF55FF), "e": Color(hex: 0xFFFF55), "f": Color(hex: 0xFFFFFF),
    ]

    static func attributedString(from raw: String, size: CGFloat = 14) -> AttributedString {
        var result = AttributedString()
        var buffer = ""
        var color = defaultColor
        var bold = false, italic = false, underline = false, strikethrough = false

        func flush() {
            guard !buffer.isEmpty else { return }
            var piece = AttributedString(buffer)
            var font = Font.system(size: size, design: .monospaced)
            if bold { font = font.bold() }
            if italic { font = font.italic() }
            piece.font = font
            piece.foregroundColor = color
            if underline { piece.underlineStyle = .single }
            if strikethrough { piece.strikethroughStyle = .single }
            result += piece
            buffer = ""
        }

        var characters = raw.makeIterator()
        while let character = characters.next() {
            guard character == "§", let code = characters.next().map({ Character($0.lowercased()) }) else {
                buffer.append(character)
                continue
            }
            flush()
            if let newColor = colors[code] {
                // A color code also clears formatting, as in the game.
                color = newColor
                bold = false; italic = false; underline = false; strikethrough = false
            } else {
                switch code {
                case "l": bold = true
                case "o": italic = true
                case "n": underline = true
                case "m": strikethrough = true
                case "r":
                    color = defaultColor
                    bold = false; italic = false; underline = false; strikethrough = false
                default: break // §k (obfuscated) is shown as plain text
                }
            }
        }
        flush()
        return result
    }
}

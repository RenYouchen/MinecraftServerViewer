//
//  PacketCoding.swift
//  MinecraftServerViewer
//
//  Big-endian / VarInt encoding shared by the Java and Bedrock protocols.
//

import Foundation

nonisolated struct PacketWriter {
    private(set) var data = Data()

    mutating func writeByte(_ byte: UInt8) {
        data.append(byte)
    }

    mutating func writeBytes(_ bytes: some Sequence<UInt8>) {
        data.append(contentsOf: bytes)
    }

    mutating func writeVarInt(_ value: Int32) {
        var remaining = UInt32(bitPattern: value)
        repeat {
            var byte = UInt8(remaining & 0x7F)
            remaining >>= 7
            if remaining != 0 { byte |= 0x80 }
            data.append(byte)
        } while remaining != 0
    }

    /// VarInt length-prefixed UTF-8 string (Java protocol).
    mutating func writeString(_ string: String) {
        let utf8 = Array(string.utf8)
        writeVarInt(Int32(utf8.count))
        writeBytes(utf8)
    }

    mutating func writeUInt16(_ value: UInt16) {
        withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) }
    }

    mutating func writeInt64(_ value: Int64) {
        withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) }
    }

    /// Prefixes the packet with its VarInt length, as Java packets are framed.
    var framed: Data {
        var frame = PacketWriter()
        frame.writeVarInt(Int32(data.count))
        frame.writeBytes(data)
        return frame.data
    }
}

nonisolated struct PacketReader {
    private let bytes: [UInt8]
    private var offset = 0

    init(_ data: Data) {
        bytes = Array(data)
    }

    var remaining: Int { bytes.count - offset }

    mutating func readBytes(_ count: Int) throws -> ArraySlice<UInt8> {
        guard count >= 0, remaining >= count else { throw ServerStatusError.badResponse }
        defer { offset += count }
        return bytes[offset..<offset + count]
    }

    mutating func readByte() throws -> UInt8 {
        try readBytes(1).first!
    }

    mutating func readVarInt() throws -> Int32 {
        var value: UInt32 = 0
        for index in 0..<5 {
            let byte = try readByte()
            value |= UInt32(byte & 0x7F) << (7 * index)
            if byte & 0x80 == 0 { return Int32(bitPattern: value) }
        }
        throw ServerStatusError.parsingFailed("VarInt 過長")
    }

    mutating func readUInt16() throws -> UInt16 {
        try readBytes(2).reduce(0) { $0 << 8 | UInt16($1) }
    }

    mutating func readInt64() throws -> Int64 {
        Int64(bitPattern: try readBytes(8).reduce(0) { $0 << 8 | UInt64($1) })
    }

    /// VarInt length-prefixed UTF-8 string (Java protocol).
    mutating func readString() throws -> String {
        let length = Int(try readVarInt())
        guard let string = String(bytes: try readBytes(length), encoding: .utf8) else {
            throw ServerStatusError.parsingFailed("字串不是有效的 UTF-8")
        }
        return string
    }
}

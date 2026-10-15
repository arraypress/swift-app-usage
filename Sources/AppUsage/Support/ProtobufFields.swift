//
//  ProtobufFields.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//
//  Just enough protobuf to read Biome events: field numbers and wire types,
//  no schema. Groups (wire types 3 and 4) do not occur and end the read.
//

import Foundation

/// Decodes a protobuf message into its fields.
public enum ProtobufFields {

    /// Every field, by number, in the order they appear.
    ///
    /// Returns what was read before anything malformed: a torn payload yields
    /// its leading fields, never a crash.
    public static func decode(_ data: Data) -> [Int: [ProtobufValue]] {
        let bytes = [UInt8](data)
        var fields: [Int: [ProtobufValue]] = [:]
        var index = 0
        while index < bytes.count {
            guard let key = varint(bytes, &index) else { break }
            let number = Int(key >> 3)
            let value: ProtobufValue
            switch key & 7 {
            case 0:
                guard let read = varint(bytes, &index) else { return fields }
                value = .varint(read)
            case 1:
                guard index + 8 <= bytes.count else { return fields }
                value = .fixed64(SEGBParser.double(bytes, at: index))
                index += 8
            case 2:
                guard let length = varint(bytes, &index), length <= UInt64(bytes.count - index) else { return fields }
                value = .bytes(Data(bytes[index..<(index + Int(length))]))
                index += Int(length)
            case 5:
                guard index + 4 <= bytes.count else { return fields }
                value = .fixed32(SEGBParser.uint32(bytes, at: index))
                index += 4
            default:
                return fields
            }
            fields[number, default: []].append(value)
        }
        return fields
    }

    /// A base-128 varint, advancing the index; `nil` when it runs off the end.
    static func varint(_ bytes: [UInt8], _ index: inout Int) -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while index < bytes.count, shift < 64 {
            let byte = bytes[index]
            index += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte < 0x80 { return result }
            shift += 7
        }
        return nil
    }

    /// The first value of a field as an integer.
    public static func integer(_ fields: [Int: [ProtobufValue]], _ number: Int) -> UInt64? {
        if case .varint(let value)? = fields[number]?.first { return value }
        return nil
    }

    /// The first value of a field as a UTF-8 string.
    public static func string(_ fields: [Int: [ProtobufValue]], _ number: Int) -> String? {
        if case .bytes(let data)? = fields[number]?.first { return String(data: data, encoding: .utf8) }
        return nil
    }

    /// The first value of a field as a double.
    public static func double(_ fields: [Int: [ProtobufValue]], _ number: Int) -> Double? {
        if case .fixed64(let value)? = fields[number]?.first { return value }
        return nil
    }
}

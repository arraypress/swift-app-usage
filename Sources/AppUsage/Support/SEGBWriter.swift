//
//  SEGBWriter.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//  The inverse of SEGBParser, for fixtures: a SEGB v2 file from entries, in
//  the layout SEGBParser documents. Biome never sees these files; tests (here
//  and in tools built on this library) build stores out of them.
//

import Foundation

/// Writes SEGB v2 files.
public enum SEGBWriter {

    /// A file holding these entries, in order.
    ///
    /// - Parameters:
    ///   - entries: each entry's state, time (seconds since 2001) and payload.
    ///   - created: the file's creation time, seconds since 2001.
    public static func file(_ entries: [(state: SEGBEntryState, stamp: Double, payload: Data)], created: Double = 0) -> Data {
        var body = [UInt8]()
        var trailer: [(end: UInt32, state: UInt32, stamp: Double)] = []
        for entry in entries {
            while body.count % 4 != 0 { body.append(0) }
            body += le(CRC32.checksum(entry.payload))
            body += le(UInt32(0))
            body += [UInt8](entry.payload)
            trailer.append((UInt32(body.count), entry.state.rawValue, entry.stamp))
        }
        var bytes = [UInt8]("SEGB".utf8)
        bytes += le(UInt32(entries.count))
        bytes += le(created.bitPattern)
        bytes += [UInt8](repeating: 0, count: 16)
        bytes += body
        // Biome preallocates; a gap between the last entry and the trailer is normal.
        bytes += [UInt8](repeating: 0, count: 64)
        for item in trailer.reversed() {
            bytes += le(item.end)
            bytes += le(item.state)
            bytes += le(item.stamp.bitPattern)
        }
        return Data(bytes)
    }

    /// A ScreenTime.AppUsage payload.
    public static func screenTimePayload(bundleID: String, date: Date, starting: Bool, trusted: Bool = true) -> Data {
        var bytes = [UInt8]()
        bytes += [0x08, starting ? 1 : 0]
        bytes += [0x11] + le(date.timeIntervalSince1970.bitPattern)
        let id = [UInt8](bundleID.utf8)
        bytes += [0x1A] + varint(UInt64(id.count)) + id
        bytes += [0x28, trusted ? 1 : 0]
        return Data(bytes)
    }

    static func le<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        withUnsafeBytes(of: value.littleEndian) { Array($0) }
    }

    static func varint(_ value: UInt64) -> [UInt8] {
        var value = value
        var bytes = [UInt8]()
        repeat {
            var byte = UInt8(value & 0x7F)
            value >>= 7
            if value != 0 { byte |= 0x80 }
            bytes.append(byte)
        } while value != 0
        return bytes
    }
}

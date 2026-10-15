//
//  SEGBParser.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//
//  Biome's SEGB (version 2) file layout, measured on macOS 27 files:
//
//    0x00  "SEGB"
//    0x04  UInt32  entry count
//    0x08  Double  file creation time (seconds since 2001)
//    0x10  16 bytes of bookkeeping
//    0x20  the entries, each starting on a 4-byte boundary:
//            UInt32 CRC-32 of the payload, UInt32 (unused here), payload
//    end   a trailer of 16 bytes per entry, written backwards from the last
//          byte of the file (entry 0 is the LAST 16 bytes):
//            UInt32 end offset of the entry, relative to 0x20
//            UInt32 state (1 written, 3 deleted, 4 bookkeeping)
//            Double the entry's time (seconds since 2001)
//
//  Files are preallocated (512 KB or 1 MB) and filled as events arrive, so
//  every read is bounds-checked: a file being written can end mid-entry.
//

import Foundation

/// Reads SEGB files.
public enum SEGBParser {

    /// The magic bytes at the start of every SEGB v2 file.
    static let magic = Data("SEGB".utf8)

    /// Where the first entry starts.
    static let dataStart = 0x20

    /// Every entry of a file, in the order written.
    ///
    /// Returns an empty list for bytes that are not a SEGB v2 file rather than
    /// throwing: a stream folder can hold a file Biome has only just created.
    public static func records(in data: Data) -> [SEGBRecord] {
        let bytes = [UInt8](data)
        guard bytes.count >= dataStart, Data(bytes[0..<4]) == magic else { return [] }
        let count = Int(uint32(bytes, at: 4))
        // The trailer cannot overlap the header.
        guard count > 0, count * 16 <= bytes.count - dataStart else { return [] }

        var records: [SEGBRecord] = []
        records.reserveCapacity(count)
        var start = dataStart
        for index in 0..<count {
            let trailer = bytes.count - 16 * (index + 1)
            let end = dataStart + Int(uint32(bytes, at: trailer))
            let stateValue = uint32(bytes, at: trailer + 4)
            let stamp = double(bytes, at: trailer + 8)
            // An entry must sit between the header and the trailer and be at
            // least its own 8-byte prefix long; anything else is a file being
            // written or damage, and stops the walk.
            guard end >= start + 8, end <= bytes.count - 16 * count else { break }
            let stored = uint32(bytes, at: start)
            let payload = Data(bytes[(start + 8)..<end])
            records.append(SEGBRecord(state: SEGBEntryState(rawValue: stateValue) ?? .unknown,
                                      stamp: stamp,
                                      payload: payload,
                                      checksumMatches: CRC32.checksum(payload) == stored))
            start = aligned(end)
        }
        return records
    }

    /// The next 4-byte boundary at or after an offset.
    static func aligned(_ offset: Int) -> Int { (offset + 3) & ~3 }

    static func uint32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
    }

    static func double(_ bytes: [UInt8], at offset: Int) -> Double {
        var bits: UInt64 = 0
        for shift in 0..<8 { bits |= UInt64(bytes[offset + shift]) << (8 * UInt64(shift)) }
        return Double(bitPattern: bits)
    }
}

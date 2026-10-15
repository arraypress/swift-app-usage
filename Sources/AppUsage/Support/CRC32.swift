//
//  CRC32.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//
//  The CRC-32 (IEEE 802.3, zlib's) SEGB stores in front of each payload.
//

import Foundation

/// CRC-32 as zlib computes it.
enum CRC32 {

    private static let table: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1
        }
        return value
    }

    /// The checksum of some bytes.
    static func checksum<Bytes: Collection>(_ bytes: Bytes) -> UInt32 where Bytes.Element == UInt8 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}

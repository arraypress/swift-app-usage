//
//  ProtobufValue.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One field value of a protobuf message, by wire type.
///
/// Biome stores events as protobuf with no schema shipped beside them, so the
/// readers here decode by field number and wire type and nothing more.
public enum ProtobufValue: Sendable, Equatable {

    /// Wire type 0.
    case varint(UInt64)

    /// Wire type 1: eight bytes, read as a double — every 64-bit fixed field
    /// in the streams read here is a timestamp.
    case fixed64(Double)

    /// Wire type 5.
    case fixed32(UInt32)

    /// Wire type 2: a string, bytes or nested message.
    case bytes(Data)
}

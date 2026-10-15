//
//  SEGBRecord.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One entry of a Biome SEGB file, as stored.
public struct SEGBRecord: Sendable, Equatable {

    /// Whether the entry is live, pruned or bookkeeping.
    public let state: SEGBEntryState

    /// The time Biome stamped the entry with, in seconds since 2001-01-01 UTC.
    public let stamp: Double

    /// The event itself: a protobuf message whose schema belongs to the stream.
    public let payload: Data

    /// Whether the payload matched the CRC-32 stored in front of it.
    ///
    /// A file is written while it is read; an entry caught half-written fails
    /// the check and is skipped by the readers.
    public let checksumMatches: Bool

    /// Creates a record.
    public init(state: SEGBEntryState, stamp: Double, payload: Data, checksumMatches: Bool) {
        self.state = state
        self.stamp = stamp
        self.payload = payload
        self.checksumMatches = checksumMatches
    }
}

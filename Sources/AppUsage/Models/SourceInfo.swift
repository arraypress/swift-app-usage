//
//  SourceInfo.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What one store holds, for `sources`.
public struct SourceInfo: Sendable, Equatable, Codable {

    /// A short stable name — `biome.screentime`, `knowledge.app-usage`.
    public let id: String

    /// What it records.
    public let summary: String

    /// Where it is.
    public let path: String

    /// Whether it exists and could be read.
    public let available: Bool

    /// Live records.
    public let records: Int

    /// The earliest record's time.
    public let earliest: Date?

    /// The latest record's time.
    public let latest: Date?

    /// What this library uses it for, or why it does not.
    public let note: String

    /// Creates a description.
    public init(id: String, summary: String, path: String, available: Bool, records: Int,
                earliest: Date?, latest: Date?, note: String) {
        self.id = id
        self.summary = summary
        self.path = path
        self.available = available
        self.records = records
        self.earliest = earliest
        self.latest = latest
        self.note = note
    }
}

//
//  AppVisit.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A visit to an app: its fragments joined across short absences.
///
/// See ``UsageSummaries/visits(_:mergeGap:)`` for the rule.
public struct AppVisit: Sendable, Equatable, Codable {

    /// The app's bundle identifier.
    public let bundleID: String

    /// When the visit began.
    public let start: Date

    /// When it ended.
    public let end: Date

    /// Time actually in front, in seconds: the absences inside are not counted.
    public let seconds: Double

    /// How many stored fragments it joins.
    public let fragments: Int

    /// Creates a visit.
    public init(bundleID: String, start: Date, end: Date, seconds: Double, fragments: Int) {
        self.bundleID = bundleID
        self.start = start
        self.end = end
        self.seconds = seconds
        self.fragments = fragments
    }
}

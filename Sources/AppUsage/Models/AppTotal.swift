//
//  AppTotal.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One app's use over a span of time.
public struct AppTotal: Sendable, Equatable, Codable {

    /// The app's bundle identifier.
    public let bundleID: String

    /// Seconds in front.
    public let seconds: Double

    /// Visits, after joining fragments across short absences.
    public let visits: Int

    /// Stored fragments, before joining.
    public let fragments: Int

    /// The first moment it was in front.
    public let first: Date

    /// The last moment it was in front.
    public let last: Date

    /// Creates a total.
    public init(bundleID: String, seconds: Double, visits: Int, fragments: Int, first: Date, last: Date) {
        self.bundleID = bundleID
        self.seconds = seconds
        self.visits = visits
        self.fragments = fragments
        self.first = first
        self.last = last
    }
}

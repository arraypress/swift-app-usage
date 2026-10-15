//
//  UsageFragment.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One unbroken spell of an app in front, as the store recorded it.
///
/// Stores cut long spells into pieces (Biome at most about 25 minutes), so a
/// fragment is a unit of storage, not of attention. ``AppVisit`` is the unit
/// of attention.
public struct UsageFragment: Sendable, Equatable, Codable {

    /// The app's bundle identifier.
    public let bundleID: String

    /// When it came to the front.
    public let start: Date

    /// When it left.
    public let end: Date

    /// Screen Time's "usage is trusted" flag, when known.
    public let trusted: Bool?

    /// Creates a fragment.
    public init(bundleID: String, start: Date, end: Date, trusted: Bool? = nil) {
        self.bundleID = bundleID
        self.start = start
        self.end = end
        self.trusted = trusted
    }
}

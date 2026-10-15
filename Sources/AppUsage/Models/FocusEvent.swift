//
//  FocusEvent.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// An app coming to the front, or leaving it.
///
/// Biome's `ScreenTime.AppUsage` stream is a list of these: each foreground
/// spell is a start event and an end event for the same bundle identifier.
public struct FocusEvent: Sendable, Equatable, Codable {

    /// The app's bundle identifier.
    public let bundleID: String

    /// When it happened.
    public let date: Date

    /// `true` when the app came to the front, `false` when it left.
    public let starting: Bool

    /// Screen Time's "usage is trusted" flag, when the event carries it.
    ///
    /// Observed false on locally built and some third-party apps; Screen Time's
    /// own use of it is not documented, so it is carried, never filtered on.
    public let trusted: Bool?

    /// Creates an event.
    public init(bundleID: String, date: Date, starting: Bool, trusted: Bool? = nil) {
        self.bundleID = bundleID
        self.date = date
        self.starting = starting
        self.trusted = trusted
    }
}

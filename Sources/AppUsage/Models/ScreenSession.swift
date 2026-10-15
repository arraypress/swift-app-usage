//
//  ScreenSession.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A spell with the display lit.
///
/// From knowledgeC.db's `/display/isBacklit` stream. On a Mac each one is a
/// wake — the nearest thing to a phone's "pickup".
public struct ScreenSession: Sendable, Equatable, Codable {

    /// When the display lit.
    public let start: Date

    /// When it went dark.
    public let end: Date

    /// Creates a session.
    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

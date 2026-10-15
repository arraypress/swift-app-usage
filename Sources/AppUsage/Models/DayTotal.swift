//
//  DayTotal.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Time on one calendar day.
public struct DayTotal: Sendable, Equatable, Codable {

    /// The start of the day, in the calendar the totals were made in.
    public let day: Date

    /// Seconds.
    public let seconds: Double

    /// Visits or sessions that day (a visit crossing midnight counts on both days).
    public let count: Int

    /// Creates a day's total.
    public init(day: Date, seconds: Double, count: Int) {
        self.day = day
        self.seconds = seconds
        self.count = count
    }
}

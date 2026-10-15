//
//  DaySplitting.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//
//  Cutting a spell at midnight, so a day's total holds only that day's time.
//

import Foundation

/// Splits spans of time at the calendar's midnights.
public enum DaySplitting {

    /// The pieces of a span, one per day it touches.
    ///
    /// - Returns: each piece with the start of its day.
    public static func split(start: Date, end: Date, calendar: Calendar) -> [(day: Date, start: Date, end: Date)] {
        guard end > start else { return [] }
        var pieces: [(day: Date, start: Date, end: Date)] = []
        var cursor = start
        while cursor < end {
            let day = calendar.startOfDay(for: cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > cursor else { break }
            let pieceEnd = min(next, end)
            pieces.append((day, cursor, pieceEnd))
            cursor = pieceEnd
        }
        return pieces
    }

    /// Seconds and a count per day, for spans of time.
    ///
    /// A span crossing midnight adds its seconds to each day in proportion
    /// and counts once on every day it touches.
    public static func days(_ spans: [(start: Date, end: Date)], calendar: Calendar) -> [DayTotal] {
        var seconds: [Date: Double] = [:]
        var counts: [Date: Int] = [:]
        for span in spans {
            for piece in split(start: span.start, end: span.end, calendar: calendar) {
                seconds[piece.day, default: 0] += piece.end.timeIntervalSince(piece.start)
                counts[piece.day, default: 0] += 1
            }
        }
        return seconds.keys.sorted().map { DayTotal(day: $0, seconds: seconds[$0] ?? 0, count: counts[$0] ?? 0) }
    }
}

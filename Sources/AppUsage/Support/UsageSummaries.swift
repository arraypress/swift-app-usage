//
//  UsageSummaries.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//
//  Fragments into what a person asks about: per-app totals, visits, a
//  timeline, days.
//
//  THE MERGE RULE. Stores keep fragments — most last seconds, because a Mac
//  user flicks between windows constantly. Totals are the sum of fragment
//  time and do not depend on merging at all. Visits do: an app's fragments
//  join into one visit when the time away between them is at most
//  `mergeGap` (60 s by default), whatever was in front meanwhile — a glance
//  at a chat is not leaving the editor. Measured on real history, joining
//  only fragments that touch changes almost nothing (switching is the norm),
//  so the gap is time away, not adjacency. The timeline is stricter: only
//  fragments of the same app that follow each other with nothing between
//  join, so it stays one strip with no overlaps.
//

import Foundation

/// Totals, visits and timelines from fragments.
public enum UsageSummaries {

    /// The default longest absence that still continues a visit, in seconds.
    public static let defaultMergeGap: TimeInterval = 60

    /// Seconds a fragment lasted.
    public static func seconds(_ fragment: UsageFragment) -> Double {
        fragment.end.timeIntervalSince(fragment.start)
    }

    /// Every app's visits, ordered by start.
    public static func visits(_ fragments: [UsageFragment], mergeGap: TimeInterval = defaultMergeGap) -> [AppVisit] {
        let byApp = Dictionary(grouping: fragments, by: \.bundleID)
        var visits: [AppVisit] = []
        for (bundleID, pieces) in byApp {
            visits += join(pieces.sorted { $0.start < $1.start }, bundleID: bundleID, mergeGap: mergeGap)
        }
        return visits.sorted { $0.start != $1.start ? $0.start < $1.start : $0.bundleID < $1.bundleID }
    }

    /// Fragments in time order, with consecutive fragments of one app joined
    /// when nothing else came between and the gap is at most `mergeGap`.
    ///
    /// - Parameter minimum: visits shorter than this many seconds are left out.
    public static func timeline(_ fragments: [UsageFragment], mergeGap: TimeInterval = defaultMergeGap,
                                minimum: TimeInterval = 0) -> [AppVisit] {
        let ordered = fragments.sorted { $0.start < $1.start }
        var runs: [[UsageFragment]] = []
        for fragment in ordered {
            if let last = runs.last?.last, last.bundleID == fragment.bundleID,
               fragment.start.timeIntervalSince(last.end) <= mergeGap {
                runs[runs.count - 1].append(fragment)
            } else {
                runs.append([fragment])
            }
        }
        return runs.compactMap { run in
            guard let first = run.first, let last = run.last else { return nil }
            let seconds = run.reduce(0) { $0 + Self.seconds($1) }
            return AppVisit(bundleID: first.bundleID, start: first.start, end: last.end,
                            seconds: seconds, fragments: run.count)
        }.filter { $0.seconds >= minimum }
    }

    /// One total per app, most used first.
    public static func totals(_ fragments: [UsageFragment], mergeGap: TimeInterval = defaultMergeGap) -> [AppTotal] {
        let visitCounts = Dictionary(grouping: visits(fragments, mergeGap: mergeGap), by: \.bundleID).mapValues(\.count)
        return Dictionary(grouping: fragments, by: \.bundleID).compactMap { bundleID, pieces -> AppTotal? in
            guard let first = pieces.map(\.start).min(), let last = pieces.map(\.end).max() else { return nil }
            return AppTotal(bundleID: bundleID,
                            seconds: pieces.reduce(0) { $0 + seconds($1) },
                            visits: visitCounts[bundleID] ?? 0,
                            fragments: pieces.count,
                            first: first, last: last)
        }.sorted { $0.seconds != $1.seconds ? $0.seconds > $1.seconds : $0.bundleID < $1.bundleID }
    }

    /// All time in front, in seconds.
    public static func totalSeconds(_ fragments: [UsageFragment]) -> Double {
        fragments.reduce(0) { $0 + seconds($1) }
    }

    /// Seconds per day; the count is the visits touching each day.
    public static func days(_ fragments: [UsageFragment], mergeGap: TimeInterval = defaultMergeGap,
                            calendar: Calendar) -> [DayTotal] {
        let time = DaySplitting.days(fragments.map { ($0.start, $0.end) }, calendar: calendar)
        let visitDays = DaySplitting.days(visits(fragments, mergeGap: mergeGap).map { ($0.start, $0.end) }, calendar: calendar)
        let counts = Dictionary(uniqueKeysWithValues: visitDays.map { ($0.day, $0.count) })
        return time.map { DayTotal(day: $0.day, seconds: $0.seconds, count: counts[$0.day] ?? 0) }
    }

    /// One app's fragments joined into visits.
    static func join(_ ordered: [UsageFragment], bundleID: String, mergeGap: TimeInterval) -> [AppVisit] {
        var visits: [AppVisit] = []
        var current: (start: Date, end: Date, seconds: Double, count: Int)?
        for fragment in ordered {
            if let open = current, fragment.start.timeIntervalSince(open.end) <= mergeGap {
                current = (open.start, max(open.end, fragment.end), open.seconds + seconds(fragment), open.count + 1)
            } else {
                if let open = current {
                    visits.append(AppVisit(bundleID: bundleID, start: open.start, end: open.end, seconds: open.seconds, fragments: open.count))
                }
                current = (fragment.start, fragment.end, seconds(fragment), 1)
            }
        }
        if let open = current {
            visits.append(AppVisit(bundleID: bundleID, start: open.start, end: open.end, seconds: open.seconds, fragments: open.count))
        }
        return visits
    }
}

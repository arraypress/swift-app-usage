//
//  FragmentBuilder.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//
//  Start and end events into fragments. The rules, each one a case met in
//  real streams:
//
//  - Events at the same instant: ends before starts, so a hand-over from one
//    app to the next never looks like both in front at once.
//  - A start for an app already open closes the open spell there and begins
//    a new one (Biome restarts a spell without an end now and then).
//  - An end with no start is dropped: its start was pruned, or fell before
//    the history this Mac keeps.
//  - A spell still open when the events run out ends at the next start of
//    any other app, or now — but never runs past `openLimit` (30 minutes by
//    default; Biome cuts spells at about 25), because a spell left open hours
//    ago is one whose end was lost, not one still going.
//

import Foundation

/// Pairs focus events into fragments.
public enum FragmentBuilder {

    /// The longest an unclosed spell is believed, in seconds.
    public static let defaultOpenLimit: TimeInterval = 1_800

    /// Fragments from events, sorted by start.
    public static func fragments(from events: [FocusEvent], now: Date,
                                 openLimit: TimeInterval = defaultOpenLimit) -> [UsageFragment] {
        let ordered = events.sorted { lhs, rhs in
            lhs.date != rhs.date ? lhs.date < rhs.date : (!lhs.starting && rhs.starting)
        }
        var open: [String: FocusEvent] = [:]
        var fragments: [UsageFragment] = []
        var starts: [Date] = []

        for event in ordered {
            if event.starting {
                if let previous = open[event.bundleID] {
                    fragments.append(UsageFragment(bundleID: previous.bundleID, start: previous.date,
                                                   end: event.date, trusted: previous.trusted))
                }
                open[event.bundleID] = event
                starts.append(event.date)
            } else if let started = open.removeValue(forKey: event.bundleID) {
                fragments.append(UsageFragment(bundleID: started.bundleID, start: started.date,
                                               end: event.date, trusted: started.trusted ?? event.trusted))
            }
        }

        for started in open.values {
            let nextStart = starts.first { $0 > started.date }
            let end = min(nextStart ?? now, now, started.date.addingTimeInterval(openLimit))
            if end > started.date {
                fragments.append(UsageFragment(bundleID: started.bundleID, start: started.date,
                                               end: end, trusted: started.trusted))
            }
        }
        return fragments.sorted { $0.start != $1.start ? $0.start < $1.start : $0.bundleID < $1.bundleID }
    }

    /// The parts of fragments that fall inside an interval.
    public static func clip(_ fragments: [UsageFragment], to interval: DateInterval) -> [UsageFragment] {
        fragments.compactMap { fragment in
            let start = max(fragment.start, interval.start)
            let end = min(fragment.end, interval.end)
            guard end > start else { return nil }
            return UsageFragment(bundleID: fragment.bundleID, start: start, end: end, trusted: fragment.trusted)
        }
    }
}

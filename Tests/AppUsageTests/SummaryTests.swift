//
//  SummaryTests.swift
//  AppUsageTests
//
//  Created by David Sherlock on 2026.
//

@testable import AppUsage
import Foundation
import Testing

struct SummaryTests {

    func event(_ bundle: String, _ hour: Double, _ starting: Bool) -> FocusEvent {
        FocusEvent(bundleID: bundle, date: at(hour), starting: starting)
    }

    @Test func eventsPairIntoFragmentsWithEndsBeforeStarts() {
        // A hand-over at the same instant, listed start-first.
        let events = [event("b", 1, true), event("a", 1, false), event("a", 0, true), event("b", 2, false)]
        let fragments = FragmentBuilder.fragments(from: events, now: at(10))
        #expect(fragments.map(\.bundleID) == ["a", "b"])
        #expect(fragments.map(\.start) == [at(0), at(1)])
        #expect(fragments.map(\.end) == [at(1), at(2)])
    }

    @Test func orphanEndsDropAndRestartsSplit() {
        let events = [event("a", 0, false), event("b", 1, true), event("b", 1.5, true), event("b", 2, false)]
        let fragments = FragmentBuilder.fragments(from: events, now: at(10))
        #expect(fragments.count == 2)
        #expect(fragments.map(\.end) == [at(1.5), at(2)])
    }

    @Test func anUnclosedSpellEndsAtTheNextStartNowOrTheLimit() {
        // Closed by the next app's start.
        var fragments = FragmentBuilder.fragments(from: [event("a", 0, true), event("b", 0.1, true), event("b", 0.2, false)], now: at(5))
        #expect(fragments.first { $0.bundleID == "a" }?.end == at(0.1))
        // Still in front: runs to now.
        fragments = FragmentBuilder.fragments(from: [event("a", 0, true)], now: at(0.25))
        #expect(fragments.first?.end == at(0.25))
        // Left open hours ago: believed for 30 minutes only.
        fragments = FragmentBuilder.fragments(from: [event("a", 0, true)], now: at(5))
        #expect(fragments.first?.end == at(0.5))
    }

    @Test func clippingCutsToTheInterval() {
        let fragment = UsageFragment(bundleID: "a", start: at(23, day: 0), end: at(1, day: 1))
        let clipped = FragmentBuilder.clip([fragment], to: DateInterval(start: at(0, day: 1), end: at(0, day: 2)))
        #expect(clipped.map(\.start) == [at(0, day: 1)])
        #expect(clipped.map(\.end) == [at(1, day: 1)])
        #expect(FragmentBuilder.clip([fragment], to: DateInterval(start: at(5, day: 1), end: at(6, day: 1))).isEmpty)
    }

    @Test func visitsJoinAcrossShortAbsencesOnly() {
        let fragments = [
            UsageFragment(bundleID: "editor", start: at(0), end: at(0).addingTimeInterval(100)),
            UsageFragment(bundleID: "chat", start: at(0).addingTimeInterval(100), end: at(0).addingTimeInterval(130)),
            UsageFragment(bundleID: "editor", start: at(0).addingTimeInterval(130), end: at(0).addingTimeInterval(200)),
            // 61 s away: a new visit.
            UsageFragment(bundleID: "editor", start: at(0).addingTimeInterval(261), end: at(0).addingTimeInterval(300)),
        ]
        let visits = UsageSummaries.visits(fragments, mergeGap: 60).filter { $0.bundleID == "editor" }
        #expect(visits.count == 2)
        #expect(visits[0].seconds == 170)
        #expect(visits[0].fragments == 2)
        #expect(UsageSummaries.visits(fragments, mergeGap: 0).filter { $0.bundleID == "editor" }.count == 3)

        let totals = UsageSummaries.totals(fragments, mergeGap: 60)
        #expect(totals.map(\.bundleID) == ["editor", "chat"])
        #expect(totals[0].seconds == 209)
        #expect(totals[0].visits == 2)
        #expect(totals[0].fragments == 3)
        #expect(totals[0].first == at(0))
        #expect(totals[0].last == at(0).addingTimeInterval(300))
        #expect(UsageSummaries.totalSeconds(fragments) == 239)
    }

    @Test func timelineJoinsOnlyNeighbours() {
        let fragments = [
            UsageFragment(bundleID: "a", start: at(0), end: at(0).addingTimeInterval(10)),
            UsageFragment(bundleID: "a", start: at(0).addingTimeInterval(15), end: at(0).addingTimeInterval(20)),
            UsageFragment(bundleID: "b", start: at(0).addingTimeInterval(20), end: at(0).addingTimeInterval(22)),
            UsageFragment(bundleID: "a", start: at(0).addingTimeInterval(22), end: at(0).addingTimeInterval(40)),
        ]
        let line = UsageSummaries.timeline(fragments, mergeGap: 60)
        #expect(line.map(\.bundleID) == ["a", "b", "a"])
        #expect(line[0].seconds == 15)
        #expect(UsageSummaries.timeline(fragments, mergeGap: 60, minimum: 5).map(\.bundleID) == ["a", "a"])
    }

    @Test func daysSplitAtMidnight() {
        let pieces = DaySplitting.split(start: at(22), end: at(26), calendar: utc)
        #expect(pieces.count == 2)
        #expect(pieces[0].day == dayOne)
        #expect(pieces[0].end.timeIntervalSince(pieces[0].start) == 7_200)
        let days = UsageSummaries.days([UsageFragment(bundleID: "a", start: at(22), end: at(26))], calendar: utc)
        #expect(days.map(\.seconds) == [7_200, 7_200])
        #expect(days.map(\.count) == [1, 1])
        #expect(DaySplitting.split(start: at(1), end: at(1), calendar: utc).isEmpty)
    }
}

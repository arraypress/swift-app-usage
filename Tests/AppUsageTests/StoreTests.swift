//
//  StoreTests.swift
//  AppUsageTests
//
//  Created by David Sherlock on 2026.
//
//  The store end to end over a fixture home.
//

@testable import AppUsage
import Foundation
import Testing

struct StoreTests {

    @Test func biomeIsTheDefaultAndTotalsItsSpells() throws {
        let fixture = try FixtureHome()
        try fixture.biome([("com.example.Editor", at(9), at(10)), ("com.example.Chat", at(10), at(10.5))],
                          extra: [(.deleted, 0, SEGBWriter.screenTimePayload(bundleID: "com.example.Pruned", date: at(8), starting: true))])
        try fixture.knowledge(usage: [("com.example.Other", at(9), at(11))])
        let store = UsageStore(locations: fixture.locations)
        #expect(try store.defaultSource() == .biome)
        let fragments = try store.fragments(in: DateInterval(start: dayOne, duration: 86_400), now: at(30))
        let totals = UsageSummaries.totals(fragments)
        #expect(totals.map(\.bundleID) == ["com.example.Editor", "com.example.Chat"])
        #expect(totals.map(\.seconds) == [3_600, 1_800])
    }

    @Test func knowledgeIsReadFromASnapshotAndSyncedRowsAreLeftOut() throws {
        let fixture = try FixtureHome()
        try fixture.knowledge(usage: [("com.example.Editor", at(9), at(9.5))],
                              syncedUsage: [("com.example.PhoneApp", at(9), at(12))])
        let store = UsageStore(locations: fixture.locations)
        #expect(try store.defaultSource() == .knowledge)
        let before = try Data(contentsOf: fixture.locations.knowledgeDatabase)
        let fragments = try store.fragments(in: DateInterval(start: dayOne, duration: 86_400))
        #expect(fragments.map(\.bundleID) == ["com.example.Editor"])
        #expect(fragments.first?.trusted == true)
        #expect(try Data(contentsOf: fixture.locations.knowledgeDatabase) == before)
        // The snapshot folder is gone afterwards.
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory()).filter { $0.hasPrefix("app-usage-") && $0.count > 20 }
        #expect(leftovers.isEmpty)
    }

    @Test func spellsCrossingTheIntervalAreCut() throws {
        let fixture = try FixtureHome()
        try fixture.biome([("com.example.Editor", at(23.75), at(24.25))])
        let store = UsageStore(locations: fixture.locations)
        let dayTwo = DateInterval(start: at(24), duration: 86_400)
        let fragments = try store.fragments(in: dayTwo, now: at(40))
        #expect(UsageSummaries.totalSeconds(fragments) == 900)
    }

    @Test func screenSessionsAndNotifications() throws {
        let fixture = try FixtureHome()
        try fixture.knowledge(backlit: [(at(8), at(9), true), (at(9), at(10), false), (at(10), at(10.5), true)],
                              notifications: [("com.example.Chat", "Receive", at(8.2)), ("com.example.Chat", "Receive", at(8.3)),
                                              ("com.example.Mail", "Receive", at(30))])
        let store = UsageStore(locations: fixture.locations)
        let day = DateInterval(start: dayOne, duration: 86_400)
        let sessions = try store.screenSessions(in: day)
        #expect(sessions.count == 2)
        #expect(sessions.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) } == 5_400)
        let notifications = try store.notifications(in: day)
        #expect(notifications.map(\.bundleID) == ["com.example.Chat", "com.example.Chat"])
        #expect(notifications.first?.kind == "Receive")
    }

    @Test func sourcesDescribeEveryStoreAndRemoteDevices() throws {
        let fixture = try FixtureHome()
        try fixture.biome([("com.example.Editor", at(9), at(10))])
        try fixture.biome([("com.example.PhoneApp", at(9), at(10))], stream: "App.InFocus", remote: "DEVICE-A")
        try fixture.knowledge(usage: [("com.example.Editor", at(9), at(9.5))], backlit: [(at(8), at(9), true)])
        let sources = try UsageStore(locations: fixture.locations).sources()
        let screenTime = try #require(sources.first { $0.id == "biome.screentime" })
        #expect(screenTime.records == 2)
        #expect(screenTime.earliest == at(9))
        #expect(screenTime.latest == at(10))
        #expect(sources.contains { $0.id == "biome.focus.remote.DEVICE-A" && $0.records == 2 })
        #expect(sources.first { $0.id == "knowledge.app-usage" }?.records == 1)
        #expect(sources.first { $0.id == "biome.web" }?.note.contains("not available") == true)
    }

    @Test func aRefusedStoreIsFullDiskAccess() throws {
        let fixture = try FixtureHome()
        try fixture.biome([("com.example.Editor", at(9), at(10))])
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: fixture.locations.biomeStreams.path)
        let store = UsageStore(locations: fixture.locations)
        #expect(throws: AppUsageError.self) { try store.defaultSource() }
        do {
            _ = try store.fragments(in: DateInterval(start: dayOne, duration: 86_400), source: .biome)
            Issue.record("expected a refusal")
        } catch {
            guard case .needsFullDiskAccess = error else { Issue.record("wrong error \(error)"); return }
        }
    }

    @Test func noStoresIsNoUsageData() throws {
        let fixture = try FixtureHome()
        #expect(throws: AppUsageError.noUsageData(fixture.home.appendingPathComponent("Library/Biome/streams").path)) {
            try UsageStore(locations: fixture.locations).defaultSource()
        }
    }

    @Test func appNamesForAnUnknownIdentifierAreEmpty() {
        let info = AppNames.info(for: "com.example.no-such-app-\(UUID().uuidString)")
        #expect(info.name == nil)
        #expect(info.path == nil)
        // Finder is everywhere.
        #expect(AppNames.info(for: "com.apple.finder").name == "Finder")
    }
}

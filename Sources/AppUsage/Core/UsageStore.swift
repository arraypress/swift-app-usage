//
//  UsageStore.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//  The one door: which app was in front when, what the display did, what
//  notifications came — this Mac only, read from the stores macOS keeps for
//  Screen Time. Everything is read, nothing is written: knowledgeC.db is
//  copied before it is opened, and Biome's files are read as bytes.
//

import Foundation

/// A Mac's app usage history.
public final class UsageStore: Sendable {

    /// Where the stores are.
    public let locations: UsageLocations

    /// Biome's per-app stream.
    static let screenTimeStream = "ScreenTime.AppUsage"

    /// Creates a store over the current user's home folder, or a fixture's.
    public init(locations: UsageLocations = UsageLocations(home: FileManager.default.homeDirectoryForCurrentUser)) {
        self.locations = locations
    }

    /// The source used when none is named: Biome's stream when this Mac has
    /// it, otherwise knowledgeC.db.
    ///
    /// - Throws: ``AppUsageError/needsFullDiskAccess(_:)`` when macOS refuses
    ///   to show either; ``AppUsageError/noUsageData(_:)`` when neither exists.
    public func defaultSource() throws(AppUsageError) -> UsageSource {
        let biome = stream(Self.screenTimeStream)
        var refused: String?
        switch biome.access {
        case .readable:
            if try !biome.localFiles().isEmpty { return .biome }
        case .refused:
            refused = biome.folder.path
        case .missing:
            // A refusal higher up reads as missing here; ask the stream root.
            if PermissionCheck.access(locations.biomeStreams.path) == .refused { refused = locations.biomeStreams.path }
        }
        switch PermissionCheck.access(locations.knowledgeDatabase.path) {
        case .readable: return .knowledge
        case .refused: throw .needsFullDiskAccess(locations.knowledgeDatabase.path)
        case .missing: break
        }
        if let refused { throw .needsFullDiskAccess(refused) }
        throw .noUsageData(locations.biomeStreams.deletingLastPathComponent().path)
    }

    /// The time each app was in front, inside an interval, cut to fit it.
    ///
    /// - Parameters:
    ///   - source: where to read; `nil` picks ``defaultSource()``.
    ///   - now: closes a spell still open (see ``FragmentBuilder``).
    public func fragments(in interval: DateInterval, source: UsageSource? = nil,
                          now: Date = Date()) throws(AppUsageError) -> [UsageFragment] {
        let chosen: UsageSource
        if let source { chosen = source } else { chosen = try defaultSource() }
        switch chosen {
        case .biome:
            let margin = FragmentBuilder.defaultOpenLimit
            let records = try stream(Self.screenTimeStream).localRecords(in: interval, margin: margin)
            let window = DateInterval(start: interval.start.addingTimeInterval(-margin),
                                      end: max(interval.end, interval.start).addingTimeInterval(margin))
            let events = records.compactMap { ScreenTimeDecoding.event(from: $0.payload) }
                .filter { window.contains($0.date) }
            return FragmentBuilder.clip(FragmentBuilder.fragments(from: events, now: now), to: interval)
        case .knowledge:
            let store = try KnowledgeStore(url: locations.knowledgeDatabase)
            return FragmentBuilder.clip(try store.appUsage(in: interval), to: interval)
        }
    }

    /// Spells with the display lit, inside an interval, cut to fit it.
    ///
    /// knowledgeC.db writes a spell when it ends, so one still going is not
    /// there yet.
    public func screenSessions(in interval: DateInterval) throws(AppUsageError) -> [ScreenSession] {
        let store = try KnowledgeStore(url: locations.knowledgeDatabase)
        return try store.screenSessions(in: interval).compactMap { session in
            let start = max(session.start, interval.start)
            let end = min(session.end, interval.end)
            return end >= start ? ScreenSession(start: start, end: end) : nil
        }
    }

    /// Notification events inside an interval.
    public func notifications(in interval: DateInterval) throws(AppUsageError) -> [NotificationEvent] {
        try KnowledgeStore(url: locations.knowledgeDatabase).notifications(in: interval)
    }

    /// What history each store holds, and from when.
    ///
    /// A store macOS refuses is listed as unavailable; only when every store
    /// is refused does this throw ``AppUsageError/needsFullDiskAccess(_:)``.
    public func sources() throws(AppUsageError) -> [SourceInfo] {
        var infos: [SourceInfo] = []
        var refused: String?

        let biomeStreams: [(id: String, stream: String, summary: String, note: String, decode: (SEGBRecord) -> Date?)] = [
            ("biome.screentime", Self.screenTimeStream, "app in front, start and end (Screen Time's own stream)",
             "the default source for app usage", { ScreenTimeDecoding.event(from: $0.payload)?.date }),
            ("biome.focus", "App.InFocus", "app in front, start and end",
             "not totalled: its spells carry on while the display sleeps", { ScreenTimeDecoding.inFocusDate(from: $0.payload) }),
            ("biome.web", "App.WebUsage", "web use by domain", "", { AppleTime.date(coreData: $0.stamp) }),
            ("biome.notifications", "Notification.Usage", "notifications", "not used: knowledgeC.db holds the same events",
             { AppleTime.date(coreData: $0.stamp) }),
        ]
        for entry in biomeStreams {
            let stream = stream(entry.stream)
            do {
                let records = try stream.localRecords()
                let dates = records.compactMap(entry.decode)
                var note = entry.note
                if entry.id == "biome.web" {
                    note = records.isEmpty ? "no live records: web use by domain is not available on this Mac"
                                           : "not decoded yet: counted only"
                }
                infos.append(SourceInfo(id: entry.id, summary: entry.summary, path: stream.folder.path,
                                        available: stream.exists, records: records.count,
                                        earliest: dates.min(), latest: dates.max(), note: note))
                for device in (try? stream.remoteDevices()) ?? [] where entry.id == "biome.focus" {
                    let remote = try stream.remoteRecords(device: device)
                    // A device folder holding only its deletion log has nothing to say.
                    guard !remote.isEmpty else { continue }
                    let remoteDates = remote.compactMap(entry.decode)
                    infos.append(SourceInfo(
                        id: "biome.focus.remote.\(device)", summary: "app in front on another device on this Apple Account",
                        path: stream.folder.appendingPathComponent("remote/\(device)").path, available: true,
                        records: remote.count, earliest: remoteDates.min(), latest: remoteDates.max(),
                        note: "synced from another device, one folder per device: listed, never counted"))
                }
            } catch {
                if case .needsFullDiskAccess(let path) = error { refused = path }
                infos.append(SourceInfo(id: entry.id, summary: entry.summary, path: stream.folder.path, available: false,
                                        records: 0, earliest: nil, latest: nil, note: "not readable: needs Full Disk Access"))
            }
        }

        let knowledgeStreams: [(id: String, stream: String, summary: String, note: String)] = [
            ("knowledge.app-usage", "/app/usage", "app in front, start and end", "the fallback source for app usage (--source knowledge)"),
            ("knowledge.display", "/display/isBacklit", "display lit and dark", "screen-on time and wakes"),
            ("knowledge.notifications", "/notification/usage", "notification events", "notification counts"),
            ("knowledge.media", "/app/mediaUsage", "audio and video playing", "not used"),
        ]
        let path = locations.knowledgeDatabase.path
        do {
            let store = try KnowledgeStore(url: locations.knowledgeDatabase)
            let stats = try store.streamStats(knowledgeStreams.map(\.stream))
            let synced = try store.syncedAppUsageRows()
            for entry in knowledgeStreams {
                let stat = stats[entry.stream]
                var note = entry.note
                if entry.stream == "/app/usage", synced > 0 { note += "; rows synced from other devices are left out" }
                infos.append(SourceInfo(id: entry.id, summary: entry.summary, path: path + " " + entry.stream,
                                        available: true, records: stat?.count ?? 0,
                                        earliest: stat?.earliest, latest: stat?.latest, note: note))
            }
        } catch {
            if case .needsFullDiskAccess(let path) = error { refused = path }
            for entry in knowledgeStreams {
                infos.append(SourceInfo(id: entry.id, summary: entry.summary, path: path + " " + entry.stream,
                                        available: false, records: 0, earliest: nil, latest: nil,
                                        note: error == .noUsageData(path) ? "no knowledgeC.db" : "not readable: needs Full Disk Access"))
            }
        }

        if let refused, !infos.contains(where: { $0.available && $0.records > 0 }) {
            throw .needsFullDiskAccess(refused)
        }
        return infos
    }

    /// A stream folder by name.
    func stream(_ name: String) -> BiomeStream {
        BiomeStream(folder: locations.biomeStreams.appendingPathComponent(name, isDirectory: true))
    }
}

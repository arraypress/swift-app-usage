//
//  KnowledgeStore.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//
//  Queries over a knowledgeC.db snapshot. Times are Core Data seconds; every
//  value is bound, never pasted into SQL. Rows another device synced in
//  (ZSOURCE with a ZDEVICEID) are left out: this library reports this Mac.
//

import Foundation

/// knowledgeC.db, read from a snapshot.
final class KnowledgeStore {

    private let snapshot: DatabaseSnapshot
    private var database: SQLiteDatabase { snapshot.database }

    /// Snapshots and opens the database.
    init(url: URL) throws(AppUsageError) {
        snapshot = try DatabaseSnapshot(of: url)
    }

    /// The `/app/usage` stream inside an interval.
    func appUsage(in interval: DateInterval) throws(AppUsageError) -> [UsageFragment] {
        let trusted = database.hasColumn("ZSTRUCTUREDMETADATA", "Z_DKDIGITALHEALTHMETADATAKEY__ISUSAGETRUSTED")
            ? "m.Z_DKDIGITALHEALTHMETADATAKEY__ISUSAGETRUSTED" : "NULL"
        let sql = """
            SELECT o.ZVALUESTRING, o.ZSTARTDATE, o.ZENDDATE, \(trusted)
            FROM ZOBJECT o
            LEFT JOIN ZSTRUCTUREDMETADATA m ON o.ZSTRUCTUREDMETADATA = m.Z_PK
            \(localOnly)
            WHERE o.ZSTREAMNAME = '/app/usage' AND o.ZENDDATE > ? AND o.ZSTARTDATE < ?\(localFilter)
            ORDER BY o.ZSTARTDATE
            """
        var fragments: [UsageFragment] = []
        try database.query(sql, bounds(interval)) { row in
            guard let bundleID = row.text(0), let start = row.double(1), let end = row.double(2), end > start else { return }
            fragments.append(UsageFragment(bundleID: bundleID, start: AppleTime.date(coreData: start),
                                           end: AppleTime.date(coreData: end), trusted: row.integer(3).map { $0 == 1 }))
        }
        return fragments
    }

    /// The `/display/isBacklit` spells with the display lit, inside an interval.
    func screenSessions(in interval: DateInterval) throws(AppUsageError) -> [ScreenSession] {
        let sql = """
            SELECT o.ZSTARTDATE, o.ZENDDATE FROM ZOBJECT o
            \(localOnly)
            WHERE o.ZSTREAMNAME = '/display/isBacklit' AND o.ZVALUEINTEGER = 1
              AND o.ZENDDATE > ? AND o.ZSTARTDATE < ?\(localFilter)
            ORDER BY o.ZSTARTDATE
            """
        var sessions: [ScreenSession] = []
        try database.query(sql, bounds(interval)) { row in
            guard let start = row.double(0), let end = row.double(1), end >= start else { return }
            sessions.append(ScreenSession(start: AppleTime.date(coreData: start), end: AppleTime.date(coreData: end)))
        }
        return sessions
    }

    /// The `/notification/usage` events inside an interval.
    func notifications(in interval: DateInterval) throws(AppUsageError) -> [NotificationEvent] {
        let bundle = database.hasColumn("ZSTRUCTUREDMETADATA", "Z_DKNOTIFICATIONUSAGEMETADATAKEY__BUNDLEID")
            ? "m.Z_DKNOTIFICATIONUSAGEMETADATAKEY__BUNDLEID" : "NULL"
        let sql = """
            SELECT \(bundle), o.ZVALUESTRING, o.ZSTARTDATE FROM ZOBJECT o
            LEFT JOIN ZSTRUCTUREDMETADATA m ON o.ZSTRUCTUREDMETADATA = m.Z_PK
            \(localOnly)
            WHERE o.ZSTREAMNAME = '/notification/usage' AND o.ZSTARTDATE >= ? AND o.ZSTARTDATE < ?\(localFilter)
            ORDER BY o.ZSTARTDATE
            """
        var events: [NotificationEvent] = []
        try database.query(sql, bounds(interval)) { row in
            guard let date = row.double(2) else { return }
            events.append(NotificationEvent(bundleID: row.text(0) ?? "unknown", kind: row.text(1) ?? "unknown",
                                            date: AppleTime.date(coreData: date)))
        }
        return events
    }

    /// Record count and time range of each named stream, local rows only.
    func streamStats(_ streams: [String]) throws(AppUsageError) -> [String: (count: Int, earliest: Date?, latest: Date?)] {
        var stats: [String: (count: Int, earliest: Date?, latest: Date?)] = [:]
        let marks = streams.map { _ in "?" }.joined(separator: ",")
        let sql = """
            SELECT o.ZSTREAMNAME, COUNT(*), MIN(o.ZSTARTDATE), MAX(o.ZENDDATE) FROM ZOBJECT o
            \(localOnly)
            WHERE o.ZSTREAMNAME IN (\(marks))\(localFilter)
            GROUP BY o.ZSTREAMNAME
            """
        try database.query(sql, streams.map(SQLiteValue.text)) { row in
            guard let name = row.text(0) else { return }
            stats[name] = (Int(row.integer(1) ?? 0), row.double(2).map(AppleTime.date(coreData:)),
                           row.double(3).map(AppleTime.date(coreData:)))
        }
        return stats
    }

    /// How many `/app/usage` rows came from other devices.
    func syncedAppUsageRows() throws(AppUsageError) -> Int {
        guard hasSourceTable else { return 0 }
        var count = 0
        try database.query("""
            SELECT COUNT(*) FROM ZOBJECT o JOIN ZSOURCE s ON o.ZSOURCE = s.Z_PK
            WHERE o.ZSTREAMNAME = '/app/usage' AND s.ZDEVICEID IS NOT NULL
            """) { row in count = Int(row.integer(0) ?? 0) }
        return count
    }

    private var hasSourceTable: Bool { database.hasColumn("ZSOURCE", "ZDEVICEID") }
    private var localOnly: String { hasSourceTable ? "LEFT JOIN ZSOURCE s ON o.ZSOURCE = s.Z_PK" : "" }
    private var localFilter: String { hasSourceTable ? " AND s.ZDEVICEID IS NULL" : "" }

    private func bounds(_ interval: DateInterval) -> [SQLiteValue] {
        [.double(AppleTime.coreData(interval.start)), .double(AppleTime.coreData(interval.end))]
    }
}

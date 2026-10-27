//
//  KnowledgeStore.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//
//  Queries over a knowledgeC.db snapshot, made and read by swift-sqlite-reader:
//  the live store is never opened. Times are Core Data seconds; every
//  value is bound, never pasted into SQL. Rows another device synced in
//  (ZSOURCE with a ZDEVICEID) are left out: this library reports this Mac.
//

import Foundation
import SQLiteReader

/// knowledgeC.db, read from a snapshot.
final class KnowledgeStore {

    private let database: SQLiteReader

    /// Snapshots and opens the database.
    init(url: URL) throws(AppUsageError) {
        do { database = try SQLiteReader(path: url, opening: .snapshot) } catch { throw AppUsageError(error) }
    }

    /// The `/app/usage` stream inside an interval.
    func appUsage(in interval: DateInterval) throws(AppUsageError) -> [UsageFragment] {
        let trusted = hasColumn("ZSTRUCTUREDMETADATA", "Z_DKDIGITALHEALTHMETADATAKEY__ISUSAGETRUSTED")
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
        try query(sql, bounds(interval)) { row in
            guard let bundleID = row[0].string, let start = row[1].double, let end = row[2].double, end > start else { return }
            fragments.append(UsageFragment(bundleID: bundleID, start: AppleTime.date(coreData: start),
                                           end: AppleTime.date(coreData: end), trusted: row[3].int.map { $0 == 1 }))
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
        try query(sql, bounds(interval)) { row in
            guard let start = row[0].double, let end = row[1].double, end >= start else { return }
            sessions.append(ScreenSession(start: AppleTime.date(coreData: start), end: AppleTime.date(coreData: end)))
        }
        return sessions
    }

    /// The `/notification/usage` events inside an interval.
    func notifications(in interval: DateInterval) throws(AppUsageError) -> [NotificationEvent] {
        let bundle = hasColumn("ZSTRUCTUREDMETADATA", "Z_DKNOTIFICATIONUSAGEMETADATAKEY__BUNDLEID")
            ? "m.Z_DKNOTIFICATIONUSAGEMETADATAKEY__BUNDLEID" : "NULL"
        let sql = """
            SELECT \(bundle), o.ZVALUESTRING, o.ZSTARTDATE FROM ZOBJECT o
            LEFT JOIN ZSTRUCTUREDMETADATA m ON o.ZSTRUCTUREDMETADATA = m.Z_PK
            \(localOnly)
            WHERE o.ZSTREAMNAME = '/notification/usage' AND o.ZSTARTDATE >= ? AND o.ZSTARTDATE < ?\(localFilter)
            ORDER BY o.ZSTARTDATE
            """
        var events: [NotificationEvent] = []
        try query(sql, bounds(interval)) { row in
            guard let date = row[2].double else { return }
            events.append(NotificationEvent(bundleID: row[0].string ?? "unknown", kind: row[1].string ?? "unknown",
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
        try query(sql, streams.map(SQLiteValue.text)) { row in
            guard let name = row[0].string else { return }
            stats[name] = (row[1].int ?? 0, row[2].double.map(AppleTime.date(coreData:)),
                           row[3].double.map(AppleTime.date(coreData:)))
        }
        return stats
    }

    /// How many `/app/usage` rows came from other devices.
    func syncedAppUsageRows() throws(AppUsageError) -> Int {
        guard hasSourceTable else { return 0 }
        var count = 0
        try query("""
            SELECT COUNT(*) FROM ZOBJECT o JOIN ZSOURCE s ON o.ZSOURCE = s.Z_PK
            WHERE o.ZSTREAMNAME = '/app/usage' AND s.ZDEVICEID IS NOT NULL
            """) { row in count = row[0].int ?? 0 }
        return count
    }

    private var hasSourceTable: Bool { hasColumn("ZSOURCE", "ZDEVICEID") }
    private var localOnly: String { hasSourceTable ? "LEFT JOIN ZSOURCE s ON o.ZSOURCE = s.Z_PK" : "" }
    private var localFilter: String { hasSourceTable ? " AND s.ZDEVICEID IS NULL" : "" }

    private func bounds(_ interval: DateInterval) -> [SQLiteValue] {
        [.real(AppleTime.coreData(interval.start)), .real(AppleTime.coreData(interval.end))]
    }

    /// Whether a table has a column — metadata columns come and go between
    /// macOS releases, and a query naming a missing one fails outright.
    private func hasColumn(_ table: String, _ column: String) -> Bool {
        database.columns(of: table).contains(column.uppercased())
    }

    /// Runs a query, reporting a failure as this library's error.
    private func query(_ sql: String, _ bindings: [SQLiteValue] = [], row: (SQLiteRow) -> Void) throws(AppUsageError) {
        do { try database.query(sql, bindings, row: row) } catch { throw AppUsageError(error) }
    }
}

//
//  Fixture.swift
//  AppUsageTests
//
//  Created by David Sherlock on 2026.
//
//  A fixture home folder: Biome's ScreenTime.AppUsage stream written with
//  SEGBWriter, and a knowledgeC.db with the real schema's relevant tables and
//  columns, left in WAL mode so the snapshot copy has a log to carry. Every
//  app and device here is invented.
//

import AppUsage
import Foundation
import SQLite3

/// A UTC Gregorian calendar, so day boundaries do not depend on the Mac running the tests.
let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// 2026-10-01 00:00 UTC.
let dayOne = Date(timeIntervalSince1970: 1_790_812_800)

/// A moment on day one.
func at(_ hour: Double, day: Int = 0) -> Date {
    dayOne.addingTimeInterval(Double(day) * 86_400 + hour * 3_600)
}

final class FixtureHome {

    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("app-usage-\(UUID().uuidString.prefix(8))")
    var home: URL { root.appendingPathComponent("home") }
    var locations: UsageLocations { UsageLocations(home: home) }

    init() throws {
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    deinit {
        _ = try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locations.biomeStreams.path)
        try? FileManager.default.removeItem(at: root)
    }

    /// Writes one Biome data file of focus spells (start and end events) into a stream.
    func biome(_ spells: [(String, Date, Date)], stream: String = "ScreenTime.AppUsage", created: Date = dayOne,
               extra: [(state: SEGBEntryState, stamp: Double, payload: Data)] = [], remote: String? = nil) throws {
        var entries: [(state: SEGBEntryState, stamp: Double, payload: Data)] = []
        for (bundle, start, end) in spells {
            entries.append((.written, start.timeIntervalSinceReferenceDate,
                            SEGBWriter.screenTimePayload(bundleID: bundle, date: start, starting: true)))
            entries.append((.written, end.timeIntervalSinceReferenceDate,
                            SEGBWriter.screenTimePayload(bundleID: bundle, date: end, starting: false)))
        }
        entries += extra
        let folder = locations.biomeStreams.appendingPathComponent(stream)
            .appendingPathComponent(remote.map { "remote/\($0)" } ?? "local")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("tombstone"), withIntermediateDirectories: true)
        let name = String(UInt64(created.timeIntervalSinceReferenceDate * 1_000_000))
        try SEGBWriter.file(entries, created: created.timeIntervalSinceReferenceDate)
            .write(to: folder.appendingPathComponent(name))
    }

    /// Writes knowledgeC.db.
    func knowledge(usage: [(String, Date, Date)] = [], backlit: [(Date, Date, Bool)] = [],
                   notifications: [(String, String, Date)] = [], syncedUsage: [(String, Date, Date)] = []) throws {
        let url = locations.knowledgeDatabase
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else { throw CocoaError(.fileWriteUnknown) }
        defer { sqlite3_close(db) }
        func run(_ sql: String) throws {
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw NSError(domain: "fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(db))])
            }
        }
        try run("PRAGMA journal_mode=WAL")
        try run("""
            CREATE TABLE ZOBJECT (Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, ZSOURCE INTEGER, ZSTRUCTUREDMETADATA INTEGER,
              ZVALUEINTEGER INTEGER, ZSTARTDATE TIMESTAMP, ZENDDATE TIMESTAMP, ZSTREAMNAME VARCHAR, ZVALUESTRING VARCHAR);
            CREATE TABLE ZSTRUCTUREDMETADATA (Z_PK INTEGER PRIMARY KEY, Z_DKDIGITALHEALTHMETADATAKEY__ISUSAGETRUSTED INTEGER,
              Z_DKNOTIFICATIONUSAGEMETADATAKEY__BUNDLEID VARCHAR);
            CREATE TABLE ZSOURCE (Z_PK INTEGER PRIMARY KEY, ZBUNDLEID VARCHAR, ZDEVICEID VARCHAR);
            INSERT INTO ZSOURCE VALUES (1, NULL, 'DEVICE-FIXTURE-0001');
            """)
        var pk = 1
        func row(_ stream: String, _ value: String?, _ integer: Int?, _ start: Date, _ end: Date,
                 trusted: Int? = nil, notificationBundle: String? = nil, source: Int? = nil) throws {
            let meta = pk
            try run("INSERT INTO ZSTRUCTUREDMETADATA VALUES (\(meta), \(trusted.map(String.init) ?? "NULL"), \(notificationBundle.map { "'\($0)'" } ?? "NULL"))")
            try run("""
                INSERT INTO ZOBJECT (Z_PK, ZSOURCE, ZSTRUCTUREDMETADATA, ZVALUEINTEGER, ZSTARTDATE, ZENDDATE, ZSTREAMNAME, ZVALUESTRING)
                VALUES (\(pk), \(source.map(String.init) ?? "NULL"), \(meta), \(integer.map(String.init) ?? "NULL"),
                \(start.timeIntervalSinceReferenceDate), \(end.timeIntervalSinceReferenceDate), '\(stream)', \(value.map { "'\($0)'" } ?? "NULL"))
                """)
            pk += 1
        }
        for (bundle, start, end) in usage { try row("/app/usage", bundle, nil, start, end, trusted: 1) }
        for (bundle, start, end) in syncedUsage { try row("/app/usage", bundle, nil, start, end, trusted: 1, source: 1) }
        for (start, end, lit) in backlit { try row("/display/isBacklit", nil, lit ? 1 : 0, start, end) }
        for (bundle, kind, date) in notifications { try row("/notification/usage", kind, nil, date, date, notificationBundle: bundle) }
    }
}

//
//  DatabaseSnapshot.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//
//  knowledgeC.db is live: macOS writes it, through a write-ahead log, while
//  this reads. Rather than open it at all, the database and its -wal/-shm
//  are copied into a private temporary folder, read there, and the folder is
//  deleted — the original is only ever read as bytes.
//

import Foundation

/// A private copy of a SQLite database and its log.
final class DatabaseSnapshot {

    /// The copied database.
    let database: SQLiteDatabase

    private let folder: URL

    /// Copies the database at `source` and opens the copy.
    init(of source: URL) throws(AppUsageError) {
        let fileManager = FileManager.default
        switch PermissionCheck.access(source.path) {
        case .readable: break
        case .missing: throw .noUsageData(source.path)
        case .refused: throw .needsFullDiskAccess(source.path)
        }
        folder = fileManager.temporaryDirectory.appendingPathComponent("app-usage-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            for suffix in ["", "-wal", "-shm"] {
                let from = URL(fileURLWithPath: source.path + suffix)
                guard suffix.isEmpty || fileManager.fileExists(atPath: from.path) else { continue }
                try fileManager.copyItem(at: from, to: folder.appendingPathComponent(source.lastPathComponent + suffix))
            }
        } catch {
            try? fileManager.removeItem(at: folder)
            if PermissionCheck.isRefusal(error) { throw .needsFullDiskAccess(source.path) }
            throw .unreadable(source.path, reason: error.localizedDescription)
        }
        do {
            database = try SQLiteDatabase(path: folder.appendingPathComponent(source.lastPathComponent).path)
        } catch {
            try? fileManager.removeItem(at: folder)
            throw error
        }
    }

    deinit { try? FileManager.default.removeItem(at: folder) }
}

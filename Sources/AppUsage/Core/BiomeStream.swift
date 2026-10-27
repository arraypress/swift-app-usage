//
//  BiomeStream.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//
//  Reading one Biome stream folder from disk. Each file is read whole (they
//  are 512 KB or 1 MB, preallocated) — Biome appends while this reads, and
//  SEGBParser stops cleanly at a half-written entry.
//

import Foundation
import SQLiteReader

/// One stream under `Library/Biome/streams/restricted`.
struct BiomeStream {

    /// The stream's folder, e.g. `…/ScreenTime.AppUsage`.
    let folder: URL

    /// Whether the folder can be read, is missing, or is refused.
    var access: FileAccess { FileChecks.access(folder.path) }

    /// Whether the folder is there and readable.
    var exists: Bool { access == .readable }

    /// This Mac's data files, by name.
    func localFiles() throws(AppUsageError) -> [String] {
        try names(in: folder.appendingPathComponent("local", isDirectory: true)).filter { BiomeFiles.creation(of: $0) != nil }
    }

    /// The device folders under `remote/`.
    func remoteDevices() throws(AppUsageError) -> [String] {
        try names(in: folder.appendingPathComponent("remote", isDirectory: true)).filter { !$0.hasPrefix(".") }.sorted()
    }

    /// Every written, intact record of this Mac's files that can fall inside
    /// an interval (all of them when `interval` is nil).
    func localRecords(in interval: DateInterval? = nil, margin: TimeInterval = 0) throws(AppUsageError) -> [SEGBRecord] {
        let local = folder.appendingPathComponent("local", isDirectory: true)
        var names = try localFiles()
        if let interval { names = BiomeFiles.relevant(names, to: interval, margin: margin) }
        return try records(of: names.map { local.appendingPathComponent($0) })
    }

    /// Every written, intact record of one remote device's files.
    func remoteRecords(device: String) throws(AppUsageError) -> [SEGBRecord] {
        let folder = folder.appendingPathComponent("remote/\(device)", isDirectory: true)
        let names = try names(in: folder).filter { BiomeFiles.creation(of: $0) != nil }
        return try records(of: names.map { folder.appendingPathComponent($0) })
    }

    private func records(of files: [URL]) throws(AppUsageError) -> [SEGBRecord] {
        var records: [SEGBRecord] = []
        for file in files {
            let data: Data
            do {
                data = try Data(contentsOf: file, options: .mappedIfSafe)
            } catch {
                if FileChecks.isRefusal(error) { throw .needsFullDiskAccess(file.path) }
                // Rotated away between listing and reading: nothing to read.
                continue
            }
            records += SEGBParser.records(in: data).filter { $0.state == .written && $0.checksumMatches }
        }
        return records
    }

    private func names(in folder: URL) throws(AppUsageError) -> [String] {
        let listing = PermissionCheck.entries(of: folder.path)
        if listing.access == .refused { throw .needsFullDiskAccess(folder.path) }
        return listing.names
    }
}

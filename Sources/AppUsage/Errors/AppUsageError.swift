//
//  AppUsageError.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong reading a Mac's usage history.
public enum AppUsageError: Error, Equatable, Sendable, LocalizedError {

    /// macOS refused to let this process read a usage store.
    ///
    /// Both stores live in places privacy protection guards: the refusal is
    /// what a missing Full Disk Access grant looks like. Carries the path.
    case needsFullDiskAccess(String)

    /// No usage store exists at all — neither Biome's stream nor knowledgeC.db.
    case noUsageData(String)

    /// A store is there and readable but could not be understood.
    case unreadable(String, reason: String)

    /// A sentence a person can act on.
    public var errorDescription: String? {
        switch self {
        case .needsFullDiskAccess(let path):
            "Not allowed to read \(path) — macOS keeps Screen Time history behind Full Disk Access"
        case .noUsageData(let path):
            "No app usage history at \(path)"
        case .unreadable(let path, let reason):
            "Could not read \(path): \(reason)"
        }
    }
}

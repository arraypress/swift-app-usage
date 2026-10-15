//
//  SEGBEntryState.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The state Biome records beside each entry of a SEGB file.
///
/// Only ``written`` entries carry an event. Biome prunes old history by
/// marking entries ``deleted`` in place — the bytes may still be there, and
/// reading them would resurrect history macOS has let go of.
public enum SEGBEntryState: UInt32, Sendable, Codable {

    /// A live entry.
    case written = 1

    /// Pruned: present in the file, no longer part of the stream.
    case deleted = 3

    /// A bookkeeping entry — at most one per file — that carries no event.
    case marker = 4

    /// Anything else, carried rather than guessed at.
    case unknown = 0
}

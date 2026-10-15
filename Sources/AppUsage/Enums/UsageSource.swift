//
//  UsageSource.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Where app usage is read from.
///
/// Both record the same thing — which app was in front, from when to when —
/// and on days both hold, their daily totals agree to within a few percent.
/// They differ in reach: Biome's `ScreenTime.AppUsage` stream is the one
/// Screen Time itself keeps and holds the longer, unbroken history;
/// knowledgeC.db's `/app/usage` stream is older, shorter, and can have
/// whole days missing.
public enum UsageSource: String, Sendable, Codable, CaseIterable {

    /// `~/Library/Biome/streams/restricted/ScreenTime.AppUsage` — the default.
    case biome

    /// The `/app/usage` stream in `~/Library/Application Support/Knowledge/knowledgeC.db`.
    case knowledge
}

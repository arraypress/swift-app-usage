//
//  BiomeFiles.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//
//  A Biome stream folder holds `local/` (this Mac), `remote/<device>/`
//  (devices on the same Apple Account) and, under each, `tombstone/` (a log
//  of deletions, not events). Each data file is named for its creation time
//  in microseconds since 2001 and holds the events from then until the next
//  file was started — which lets a reader skip files outside an interval.
//

import Foundation

/// Naming and choosing Biome's stream files.
public enum BiomeFiles {

    /// A file's creation time, from its name; `nil` for anything that is not
    /// a data file (`tombstone`, `lock`, stray names).
    public static func creation(of name: String) -> Date? {
        guard !name.isEmpty, name.allSatisfy(\.isNumber), let micro = UInt64(name) else { return nil }
        return Date(timeIntervalSinceReferenceDate: Double(micro) / 1_000_000)
    }

    /// The data files that can hold events inside an interval, oldest first.
    ///
    /// File i covers its creation time up to file i+1's; it is kept when that
    /// span, widened by `margin` each way, meets the interval. The margin lets
    /// a spell that began just before the interval find its start.
    public static func relevant(_ names: [String], to interval: DateInterval, margin: TimeInterval) -> [String] {
        let dated = names.compactMap { name in creation(of: name).map { (name, $0) } }.sorted { $0.1 < $1.1 }
        return dated.enumerated().compactMap { index, file in
            let next = index + 1 < dated.count ? dated[index + 1].1 : Date.distantFuture
            let covers = file.1.addingTimeInterval(-margin) <= interval.end && next.addingTimeInterval(margin) >= interval.start
            return covers ? file.0 : nil
        }
    }
}

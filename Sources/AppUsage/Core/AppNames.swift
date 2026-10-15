//
//  AppNames.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//
//  Bundle identifiers into the names Finder shows, through LaunchServices.
//

import CoreServices
import Foundation

/// Naming apps.
public enum AppNames {

    /// The installed app with a bundle identifier, named.
    ///
    /// The first app LaunchServices lists wins (it orders the preferred copy
    /// first). An identifier no installed app has — a removed app, a system
    /// service such as `_SYSTEM_CENTER_` — comes back with no name or path.
    public static func info(for bundleID: String) -> AppInfo {
        guard !bundleID.isEmpty,
              let urls = LSCopyApplicationURLsForBundleIdentifier(bundleID as CFString, nil)?.takeRetainedValue() as? [URL],
              let url = urls.first else {
            return AppInfo(bundleID: bundleID, name: nil, path: nil)
        }
        return AppInfo(bundleID: bundleID, name: displayName(of: url), path: url.path)
    }

    /// Several at once, keyed by identifier.
    public static func infos(for bundleIDs: some Sequence<String>) -> [String: AppInfo] {
        var infos: [String: AppInfo] = [:]
        for bundleID in bundleIDs where infos[bundleID] == nil { infos[bundleID] = info(for: bundleID) }
        return infos
    }

    /// Finder's name for an app bundle, without `.app`.
    static func displayName(of url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}

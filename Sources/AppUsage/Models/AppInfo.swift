//
//  AppInfo.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// An app, named.
public struct AppInfo: Sendable, Equatable, Codable {

    /// The bundle identifier.
    public let bundleID: String

    /// The name Finder shows, or `nil` when no installed app has the identifier.
    public let name: String?

    /// Where the app is, when LaunchServices knows.
    public let path: String?

    /// Creates an app description.
    public init(bundleID: String, name: String?, path: String?) {
        self.bundleID = bundleID
        self.name = name
        self.path = path
    }
}

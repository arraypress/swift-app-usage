//
//  UsageLocations.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Where the stores are.
///
/// Live, they hang off the home folder; a test points `home` at a fixture.
public struct UsageLocations: Sendable, Equatable {

    /// The home folder everything is found under.
    public let home: URL

    /// `Library/Biome/streams/restricted`.
    public let biomeStreams: URL

    /// `Library/Application Support/Knowledge/knowledgeC.db`.
    public let knowledgeDatabase: URL

    /// Creates locations under a home folder.
    public init(home: URL) {
        self.home = home
        biomeStreams = home.appendingPathComponent("Library/Biome/streams/restricted", isDirectory: true)
        knowledgeDatabase = home.appendingPathComponent("Library/Application Support/Knowledge/knowledgeC.db")
    }
}

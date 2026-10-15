//
//  NotificationEvent.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Something that happened to a notification.
///
/// From knowledgeC.db's `/notification/usage` stream.
public struct NotificationEvent: Sendable, Equatable, Codable {

    /// The app (or system service) the notification came from.
    public let bundleID: String

    /// What happened, as the store names it — `Receive`, for one.
    public let kind: String

    /// When.
    public let date: Date

    /// Creates an event.
    public init(bundleID: String, kind: String, date: Date) {
        self.bundleID = bundleID
        self.kind = kind
        self.date = date
    }
}

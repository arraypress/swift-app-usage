//
//  ScreenTimeDecoding.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//
//  The ScreenTime.AppUsage event, field by field (macOS 27, measured):
//
//    1  varint   1 = came to the front, 0 = left it
//    2  fixed64  when, in seconds since 1970
//    3  bytes    bundle identifier
//    5  varint   "usage is trusted" (matches knowledgeC's
//                ZDKDIGITALHEALTHMETADATAKEY__ISUSAGETRUSTED)
//
//  App.InFocus carries the same facts at other numbers (3 starting, 4 time on
//  the 2001 clock, 6 bundle identifier) but its spells do not end when the
//  display sleeps, so it is only described, never totalled.
//

import Foundation

/// Turns ScreenTime.AppUsage payloads into events.
public enum ScreenTimeDecoding {

    /// The event in a payload, or `nil` when a field it needs is missing.
    public static func event(from payload: Data) -> FocusEvent? {
        let fields = ProtobufFields.decode(payload)
        guard let bundleID = ProtobufFields.string(fields, 3), !bundleID.isEmpty,
              let seconds = ProtobufFields.double(fields, 2) else { return nil }
        let starting = ProtobufFields.integer(fields, 1) ?? 0
        return FocusEvent(bundleID: bundleID,
                          date: AppleTime.date(either: seconds),
                          starting: starting == 1,
                          trusted: ProtobufFields.integer(fields, 5).map { $0 == 1 })
    }

    /// The time an App.InFocus payload carries, for describing that stream.
    public static func inFocusDate(from payload: Data) -> Date? {
        ProtobufFields.double(ProtobufFields.decode(payload), 4).map(AppleTime.date(either:))
    }
}

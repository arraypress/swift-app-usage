//
//  AppleTime.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//
//  The two clocks the stores use. knowledgeC.db and SEGB file entries count
//  from 2001-01-01 (Core Data's reference date); the ScreenTime.AppUsage
//  payload counts from 1970.
//

import Foundation

/// Converting the stores' timestamps.
public enum AppleTime {

    /// Seconds between 1970-01-01 and 2001-01-01.
    public static let referenceOffset: Double = 978_307_200

    /// A Core Data timestamp (seconds since 2001) as a date.
    public static func date(coreData seconds: Double) -> Date {
        Date(timeIntervalSinceReferenceDate: seconds)
    }

    /// A timestamp from a field that could be on either clock.
    ///
    /// Anything past 1.2 billion is read as Unix time: on the 2001 clock that
    /// would be the year 2039, and on the 1970 clock it is 2008 onward — so
    /// every date a Mac running Biome can have recorded lands on one side.
    public static func date(either seconds: Double) -> Date {
        seconds > 1_200_000_000 ? Date(timeIntervalSince1970: seconds) : Date(timeIntervalSinceReferenceDate: seconds)
    }

    /// A date as Core Data seconds, for a query bound.
    public static func coreData(_ date: Date) -> Double {
        date.timeIntervalSinceReferenceDate
    }
}

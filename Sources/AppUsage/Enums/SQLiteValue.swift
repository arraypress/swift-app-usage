//
//  SQLiteValue.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A value bound into a query.
enum SQLiteValue {

    /// A REAL — the stores' timestamps.
    case double(Double)

    /// TEXT — stream names.
    case text(String)
}

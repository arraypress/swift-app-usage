//
//  PermissionCheck.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//  Telling "macOS said no" from "it is not there" when listing a folder.
//  Privacy protection refuses with EPERM (TCC) and plain permissions with
//  EACCES — but Foundation reports a refusal on a PARENT folder as "file not
//  found", so the listing asks the kernel directly with opendir(3). Files
//  and errors are classified by swift-sqlite-reader's FileChecks.
//

import Foundation
import SQLiteReader

/// Listing folders.
enum PermissionCheck {

    /// A folder's entries, or why not.
    static func entries(of path: String) -> (names: [String], access: FileAccess) {
        guard let directory = opendir(path) else {
            return ([], FileChecks.isRefusal(errno: errno) ? .refused : .missing)
        }
        defer { closedir(directory) }
        var names: [String] = []
        while let entry = readdir(directory) {
            let name = withUnsafeBytes(of: entry.pointee.d_name) { raw in
                String(decoding: raw.prefix(Int(entry.pointee.d_namlen)), as: UTF8.self)
            }
            if name != "." && name != ".." { names.append(name) }
        }
        return (names, .readable)
    }
}

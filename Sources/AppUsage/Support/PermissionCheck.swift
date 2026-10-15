//
//  PermissionCheck.swift
//  AppUsage
//
//  Created by David Sherlock on 2026.
//
//  Telling "macOS said no" from "it is not there". Privacy protection
//  refuses with EPERM (TCC) and plain permissions with EACCES — but
//  Foundation reports a refusal on a PARENT folder as "file not found", so
//  every check here asks the kernel directly with open(2)/opendir(3).
//

import Foundation

/// Classifying paths and file errors.
enum PermissionCheck {

    /// What opening a path for reading finds.
    enum Access: Equatable {
        case readable
        case missing
        case refused
    }

    /// Whether a file or folder can be opened for reading.
    static func access(_ path: String) -> Access {
        let descriptor = open(path, O_RDONLY)
        if descriptor >= 0 {
            close(descriptor)
            return .readable
        }
        return isRefusal(errno: errno) ? .refused : .missing
    }

    /// A folder's entries, or why not.
    static func entries(of path: String) -> (names: [String], access: Access) {
        guard let directory = opendir(path) else {
            return ([], isRefusal(errno: errno) ? .refused : .missing)
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

    /// Whether an error is a refusal to read.
    static func isRefusal(_ error: any Error) -> Bool {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain, error.code == NSFileReadNoPermissionError { return true }
        if error.domain == NSPOSIXErrorDomain, error.code == Int(EPERM) || error.code == Int(EACCES) { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError { return isRefusal(underlying) }
        return false
    }

    /// Whether an errno is a refusal.
    static func isRefusal(errno code: Int32) -> Bool { code == EPERM || code == EACCES }
}

//
//  FileExistence.swift
//  Ordered Copy
//
//  Copyright © 2026 Stephen Lardieri. All rights reserved.
//

import Foundation

// Credit: Christian Tietze, https://christiantietze.de/posts/2017/01/file-existence-swift/

extension FileManager {
    enum Existence: Equatable {
        case none
        case file
        case directory
    }

    func exists(_ url: URL) -> Existence {
        var isDirectory: ObjCBool = false
        let exists = self.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)

        switch (exists, isDirectory.boolValue) {
            case (false, _): return .none
            case (true, false): return .file
            case (true, true): return .directory
        }
    }
}

extension FileManager.Existence {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
            case (.none, .none),
                (.file, .file),
                (.directory, .directory):
                return true

            default: return false
        }
    }
}

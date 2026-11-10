//
//  stderr.swift
//  Ordered Copy
//
//  Copyright © 2026 Stephen Lardieri. All rights reserved.
//

import Foundation

struct StandardErrorStream: TextOutputStream {
    mutating func write(_ string: String) {
        let data = string.data(using: .utf8)!
        FileHandle.standardError.write(data)
    }
}

var stderr = StandardErrorStream()

//
//  File system.swift
//  Ordered Copy
//
//  Copyright © 2026 Stephen Lardieri. All rights reserved.
//

import Foundation

func getRawFileSystemType(for url: URL) -> String? {
    let path = url.path(percentEncoded: false)
    var stats = statfs()
    if statfs(path, &stats) == 0 {
        let typeName = withUnsafePointer(to: &stats.f_fstypename) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MFSNAMELEN)) {
                String(cString: $0)
            }
        }
        return typeName
    }
    return nil
}

//
//  main.swift
//  Ordered Copy
//
//  Copyright © 2026 Stephen Lardieri. All rights reserved.
//

import Foundation

// TODO: Parse command-line parameters.
fileprivate let singleThreaded = false
fileprivate let recursive = true
fileprivate let filter = FileOperations.Filter.default
fileprivate let criteria = DirectoryContents.MP3SortCriteria.default
fileprivate let sourcePath = "/Users/foo/Music"

print("Scanning \(sourcePath)")

fileprivate let fileOperations = FileOperations(recursive: recursive, singleThreaded: singleThreaded)
fileprivate let sourceURL = URL(fileURLWithPath: sourcePath)

fileprivate let startTime = ContinuousClock.now

// Apple developer forums say this is supposed to be faster for recursive scanning. It isn’t.
//     fileprivate let directoryContents = fileOperations.enumerate(directory: sourceURL, filter: filter)
// Instead, just walk subdirectories ourselves:
fileprivate let directoryContents = fileOperations.getDirectoryContents(of: sourceURL, filter: filter)

fileprivate let endTime = ContinuousClock.now
fileprivate let duration = endTime - startTime

guard let directoryContents else {
    fail("Failed to read source directory contents.")
}

directoryContents.sort(criteria: criteria)

// TODO: Copy the files. For right now, just print them.
fileprivate let description = directoryContents.description
print(description)
print("Scanning duration: \(duration)")

// MARK: - Helpers

fileprivate func fail(_ message: String) -> Never {
    print(message, to: &stderr)
    exit(EXIT_FAILURE)
}

//
//  main.swift
//  Ordered Copy
//
//  Copyright © 2026 Stephen Lardieri. All rights reserved.
//

import Foundation
import ArgumentParser

fileprivate let arguments = Arguments.parseOrExit()

fileprivate let singleThreaded = arguments.singleThreaded
fileprivate let recursive = arguments.recursive
fileprivate let filter = arguments.filter
fileprivate let criteria = arguments.sort
fileprivate let sourcePath = arguments.sourceDirectory
fileprivate let destinationPath = arguments.destinationDirectory

fileprivate let sourceURL = URL(fileURLWithPath: sourcePath).adjusted
fileprivate let destinationURL = URL(filePath: destinationPath, directoryHint: .isDirectory).adjusted
// TODO: When and how can .adjusted fail for a dir that doesn't exist yet?

checkFileSystem(for: destinationURL)

fileprivate let fileOperations = FileOperations(recursive: recursive, singleThreaded: singleThreaded)

print("Scanning \(sourceURL.path(percentEncoded: false))")

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

print("Scanning duration: \(duration)")

fileOperations.copyDirectory(directoryContents: directoryContents, to: destinationURL)

exit(0)

// MARK: - Helpers

fileprivate func fail(_ message: String) -> Never {
    print(message, to: &stderr)
    exit(EXIT_FAILURE)
}

fileprivate func checkFileSystem(for url: URL) {
    if let typename = getRawFileSystemType(for: url) {
        if typename != "msdos" && typename != "exfat" {
            print("Warning: destination volume is not formatted as FAT32 (“MS-DOS”) or exFAT. Ordering may not have any effect.")
        }
    }
}

// MARK: - Extensions

fileprivate extension URL {
    var adjusted: URL {
        var adjusted = self

        adjusted = adjusted.standardizedFileURL
        adjusted = adjusted.resolvingSymlinksInPath()
        adjusted = adjusted.absoluteURL

        let originalPath = self.path(percentEncoded: false)
        let adjustedPath = adjusted.path(percentEncoded: false)
        if originalPath.caseInsensitiveCompare(adjustedPath) != .orderedSame {
            print("Adjusted\n\t\(originalPath)\nto\n\t\(adjustedPath)")
        }

        return adjusted
    }
}

//
//  Arguments.swift
//  Ordered Copy
//
//  Copyright © 2026 Stephen Lardieri. All rights reserved.
//

import ArgumentParser
import Foundation

struct Arguments: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ocp",
        abstract: "Copy files onto a storage device in natural playback order."
    )

    @Flag(name: .customShort("R"), help: "Recursively copy all subdirectories under <source-directory>.")
    var recursive = false

    @Option(help: ArgumentHelp("Copy only files of the specified types. Example: --include mp3,ac3,wma",
                               valueName: "ext,ext,..."),
            transform: { try Arguments.extensionList($0) })
    var include: [String]?

    @Option(help: ArgumentHelp("Copy all files except files of the specified types. Example: --exclude jpg,png",
                               valueName: "ext,ext,..."),
            transform: { try Arguments.extensionList($0) })
    var exclude: [String]?

    @Flag(help: "Copy all files, except hidden files (unless --include-hidden is specified).")
    var includeAll = false

    @Flag(help: "With --include-all, also copy files and directories that start with a dot (.).")
    var includeHidden = false

    @Option(help: ArgumentHelp("""
                How to order MP3 files. Specify one or more of album, artist, filename, title, track \
                in tie-breaking order. MP3 files without ID3 tags, and files that are not MP3, are \
                ordered by filename and come after MP3 files with ID3 tags. \
                Default: artist,album,track,filename
                """,
                valueName: "tag,tag,..."),
            transform: { try Arguments.sortList($0) })
    var sort: [DirectoryContents.MP3SortCriteria] = DirectoryContents.MP3SortCriteria.default

    @Flag(help: .hidden)
    var singleThreaded = false

    @Argument(help: "Path to the directory with the files to copy.")
    var sourceDirectory: String

    @Argument(help: "Path to the directory that receives the files. Created if it doesn’t exist.")
    var destinationDirectory: String

    mutating func validate() throws {
        let selectionCount = [include != nil, exclude != nil, includeAll].filter { $0 }.count
        if selectionCount > 1 {
            throw ValidationError("You can only specify one of --include, --exclude, or --include-all.")
        }

        if includeHidden && !includeAll {
            throw ValidationError("--include-hidden can only be used with --include-all.")
        }

        if sourceDirectory.isEmpty {
            throw ValidationError("<source-directory> must not be empty.")
        }

        if destinationDirectory.isEmpty {
            throw ValidationError("<destination-directory> must not be empty.")
        }
    }

    var filter: FileOperations.Filter {
        if let include { return .include(extensions: include) }
        if let exclude { return .exclude(extensions: exclude) }
        if includeAll { return .all(includeHidden: includeHidden) }
        return .default
    }
}

// MARK: - Value parsing

extension Arguments {
    /// Parses a comma-separated list of file extensions, e.g. "mp3, .AC3,wma" -> ["mp3", "ac3", "wma"].
    static func extensionList(_ string: String) throws -> [String] {
        try commaSeparatedItems(string).map { item in
            let trimmed = item.hasPrefix(".") ? String(item.dropFirst()) : item
            guard !trimmed.isEmpty else {
                throw ValidationError("Invalid file extension “\(item)”.")
            }
            return trimmed.lowercased()
        }
    }

    /// Parses a comma-separated list of sort keys, e.g. "artist,album" -> [.artist, .album].
    static func sortList(_ string: String) throws -> [DirectoryContents.MP3SortCriteria] {
        var criteria: [DirectoryContents.MP3SortCriteria] = []

        for item in try commaSeparatedItems(string) {
            guard let criterion = DirectoryContents.MP3SortCriteria(rawValue: item.lowercased()) else {
                let validKeys = DirectoryContents.MP3SortCriteria.allCases.map(\.rawValue).joined(separator: ", ")
                throw ValidationError("Unknown sort key “\(item)”. Valid keys are: \(validKeys).")
            }
            guard !criteria.contains(criterion) else {
                throw ValidationError("Sort key “\(item)” is specified more than once.")
            }
            criteria.append(criterion)
        }

        return criteria
    }

    /// Splits on commas and trims whitespace. Throws if the list or any item is empty.
    private static func commaSeparatedItems(_ string: String) throws -> [String] {
        let items = string
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        guard !items.contains(where: \.isEmpty) else {
            throw ValidationError("Empty item in list “\(string)”.")
        }

        return items
    }
}

//
//  DirectoryContents.swift
//  Ordered Copy
//
//  Copyright © 2026 Stephen Lardieri. All rights reserved.
//

import Foundation

class DirectoryContents {
    init(path: String) {
        // Serial queue to write to the arrays, because arrays are not thread-safe.
        safetyQueue = OperationQueue()
        safetyQueue.qualityOfService = .utility
        safetyQueue.maxConcurrentOperationCount = 1
        safetyQueue.name = "\(String(describing: Self.self)) array safety queue for \(path)"
    }
    
    // ❗️ May be called concurrently ❗️
    func add(mp3 url: URL, tagInfo: TagInfo) {
        assert(!sorted, "\(String(describing: Self.self)): Can’t add new items after calling sort()!")

        let file = MP3File(url: url, tagInfo: tagInfo)

        safetyQueue.addOperation { [weak self] in
            guard let self else { return }
            self.mp3Files.append(file)
        }
    }

    // ❗️ May be called concurrently ❗️
    func add(other url: URL) {
        assert(!sorted, "\(String(describing: Self.self)): Can’t add new items after calling sort()!")

        let file = OtherFile(url: url)

        safetyQueue.addOperation { [weak self] in
            guard let self else { return }
            self.otherFiles.append(file)
        }
    }

    // ❗️ May be called concurrently ❗️
    func add(subdirectory url: URL, contents: DirectoryContents) {
        assert(!sorted, "\(String(describing: Self.self)): Can’t add new items after calling sort()!")

        let directory = Directory(url: url, contents: contents)

        safetyQueue.addOperation { [weak self] in
            guard let self else { return }
            self.subdirectories.append(directory)
        }
    }

    func sort(criteria: [MP3SortCriteria]) {
        let name = "\(String(describing: Self.self)) sorting queue"
        if let currentQueue = OperationQueue.current, let currentName = currentQueue.name {
            assert(name != currentName, "Do not call public sort() recursively! Call private sort() and pass in the sorting queue.")
        }

        let sortingQueue = OperationQueue()
        sortingQueue.name = name
        sortingQueue.qualityOfService = .utility
        sortingQueue.maxConcurrentOperationCount = OperationQueue.defaultMaxConcurrentOperationCount

        sort(criteria: criteria, on: sortingQueue)

        sortingQueue.waitUntilAllOperationsAreFinished()
    }

    private func sort(criteria: [MP3SortCriteria], on sortingQueue: OperationQueue) {
        assert(!sorted, "\(String(describing: Self.self)): Only call sort() once!")
        sorted = true

        safetyQueue.waitUntilAllOperationsAreFinished()

        sortingQueue.addOperation {
            self.mp3Files.sort(by: compareMP3s(leftFile:rightFile:))
        }

        sortingQueue.addOperation {
            self.otherFiles.sort(by: compareFilenames(leftFile:rightFile:))
        }

        sortingQueue.addOperation {
            self.subdirectories.sort(by: compareFilenames(leftFile:rightFile:))
        }

        for subdirectory in subdirectories {
            sortingQueue.addOperation {
                subdirectory.contents.sort(criteria: criteria, on: sortingQueue)
            }
        }

        func compareFilenames(leftFile: ContentItem, rightFile: ContentItem) -> Bool {
            let leftName = leftFile.name
            let rightName = rightFile.name
            return leftName.caseInsensitiveCompare(rightName) == .orderedAscending
        }

        func compareMP3s(leftFile: MP3File, rightFile: MP3File) -> Bool {
            for criterion in criteria {
                let leftField = field(in: leftFile, for: criterion)
                let rightField = field(in: rightFile, for: criterion)

                switch (leftField, rightField) {
                    case let (leftField as String, rightField as String):
                        switch leftField.caseInsensitiveCompare(rightField) {
                            case .orderedAscending: return true
                            case .orderedDescending: return false
                            case .orderedSame: continue
                        }

                    case let (leftField as Int, rightField as Int):
                        if leftField < rightField { return true }
                        else if leftField > rightField { return false }
                        else { continue }

                    case (_?, _?):
                        // If we add support for a new field that is neither a string nor an int, need to write a new case for it.
                        fatalError()

                    case (_?, nil):
                        // Non-nil comes before nil.
                        return true

                    case (nil, _?):
                        // Nil goes after non-nil.
                        return false

                    case (nil, nil):
                        continue
                }
            }

            // Fallback: filename is always a tie-breaker, because you can't have two files with the same name in the same directory.
            return compareFilenames(leftFile: leftFile, rightFile: rightFile)

            func field(in file: MP3File, for criterion: MP3SortCriteria) -> any Comparable? {
                return switch criterion {
                    case .artist: file.tagInfo.artist
                    case .album: file.tagInfo.album
                    case .track: file.tagInfo.track
                    case .filename: file.name
                    case .title: file.tagInfo.title
                }
            }
        }
    }

    func sortedMP3Files() -> [MP3File] {
        assert(sorted, "\(String(describing: Self.self)): Must call sort() before accessing the contents")
        return mp3Files
    }

    func sortedOtherFiles() -> [OtherFile] {
        assert(sorted, "\(String(describing: Self.self)): Must call sort() before accessing the contents")
        return otherFiles
    }

    func sortedSubdirectories() -> [Directory] {
        assert(sorted, "\(String(describing: Self.self)): Must call sort() before accessing the contents")
        return subdirectories
    }

    private var sorted = false

    private var mp3Files: [MP3File] = []
    private var otherFiles: [OtherFile] = []
    private var subdirectories: [Directory] = []

    private let safetyQueue: OperationQueue
}

extension DirectoryContents {
    enum MP3SortCriteria {
        case artist
        case album
        case track
        case filename
        case title
    }
}

extension DirectoryContents.MP3SortCriteria {
    static let `default`: [Self] = [.artist, .album, .track, .filename]
}

extension DirectoryContents {
    protocol ContentItem {
        var name: String { get }
    }

    struct MP3File: ContentItem {
        let url: URL
        let name: String
        let tagInfo: TagInfo

        init(url: URL, tagInfo: TagInfo) {
            self.url = url
            self.name = url.lastPathComponent
            self.tagInfo = tagInfo
        }
    }

    struct OtherFile: ContentItem {
        let url: URL
        let name: String

        init(url: URL) {
            self.url = url
            self.name = url.lastPathComponent
        }
    }

    struct Directory: ContentItem {
        let url: URL
        let name: String
        let contents: DirectoryContents

        init(url: URL, contents: DirectoryContents) {
            self.url = url
            self.name = url.lastPathComponent
            self.contents = contents
        }
    }
}

extension DirectoryContents: CustomStringConvertible {
    var description: String {
        var descriptionString: String = ""
        appendDescription(to: &descriptionString, indentation: 0)
        return descriptionString
    }

    private func appendDescription(to descriptionString: inout String, indentation: Int) {
        let tabs = String(repeating: "\t", count: indentation)

        for file in mp3Files {
            let name = file.name
            descriptionString.append("\(tabs)\(name)\n")
        }

        for file in otherFiles {
            let name = file.name
            descriptionString.append("\(tabs)\(name)\n")
        }

        for subdirectory in subdirectories {
            let name = subdirectory.name
            descriptionString.append("\(tabs)\(name)/\n")
            subdirectory.contents.appendDescription(to: &descriptionString, indentation: indentation + 1)
        }
    }
}

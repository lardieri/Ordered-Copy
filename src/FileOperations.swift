//
//  FileOperations.swift
//  Ordered Copy
//
//  Copyright © 2026 Stephen Lardieri. All rights reserved.
//

import Foundation

class FileOperations {
    init(recursive: Bool, singleThreaded: Bool = false) {
        self.recursive = recursive
        self.singleThreaded = singleThreaded
    }

    func getDirectoryContents(of directory: URL, filter: Filter) -> DirectoryContents? {
        if let currentQueue = OperationQueue.current,
           let name = currentQueue.name {
            assert(!name.hasPrefix(String(describing: Self.self)), "\(String(describing: Self.self)) called public method recursively!")
        }

        let path = directory.absoluteURL.path(percentEncoded: false)

        do {
            let resourceValues = try directory.resourceValues(forKeys: keys)

            let isDirectory = resourceValues.isDirectory!
            let isPackage = resourceValues.isPackage!
            let isReadable = resourceValues.isReadable!
            let isExecutable = resourceValues.isExecutable!

            guard isDirectory && !isPackage && isReadable && isExecutable else {
                print("\(path): not a readable directory")
                return nil
            }
        } catch {
            let errorMessage = error.localizedDescription
            print("Error reading \(path): \(errorMessage)")
            return nil
        }

        let queue = OperationQueue()
        queue.name = "\(String(describing: Self.self)) reading \(path)"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = singleThreaded ? 1 : OperationQueue.defaultMaxConcurrentOperationCount

        let directoryContents = getDirectoryContents(of: directory, filter: filter, on: queue)

        queue.waitUntilAllOperationsAreFinished()

        return directoryContents
    }

    private func getDirectoryContents(of directory: URL, filter: Filter, on queue: OperationQueue) -> DirectoryContents? {
        let includeHidden = if case .all(let includeHidden) = filter { includeHidden } else { false }
        let options: FileManager.DirectoryEnumerationOptions = includeHidden ? [] : [.skipsHiddenFiles]

        var path: String
        path = directory.absoluteURL.path(percentEncoded: false)

        let directoryContents = DirectoryContents(path: path)

        do {
            let allItems = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys), options: options)

            for item in allItems {
                path = item.absoluteURL.path(percentEncoded: false)
                let resourceValues = try item.resourceValues(forKeys: keys)

                let isDirectory = resourceValues.isDirectory!

                if isDirectory {
                    if recursive {
                        add(subdirectory: item, to: directoryContents, filter: filter, on: queue)
                    } else {
                        // Ignore subdirectories.
                    }
                } else {
                    add(file: item, to: directoryContents, filter: filter, on: queue)
                }
            }
        } catch {
            let errorMessage = error.localizedDescription
            print("Error reading \(path): \(errorMessage)")
            return nil
        }

        return directoryContents
    }

    private func add(subdirectory: URL, to directoryContents: DirectoryContents, filter: Filter, on queue: OperationQueue) {
        let resourceValues = try! subdirectory.resourceValues(forKeys: keys)

        let isPackage = resourceValues.isPackage!
        let isReadable = resourceValues.isReadable!
        let isExecutable = resourceValues.isExecutable!

        guard !isPackage && isReadable && isExecutable else {
            let path = subdirectory.absoluteURL.path(percentEncoded: false)
            print("\(path): not a readable directory")
            return
        }

        queue.addOperation { [weak self, weak directoryContents] in
            guard let self else { return }
            guard let directoryContents else { return }

            if let subdirectoryContents = self.getDirectoryContents(of: subdirectory, filter: filter, on: queue) {
                directoryContents.add(subdirectory: subdirectory, contents: subdirectoryContents)
            }
        }
    }

    private func add(file: URL, to directoryContents: DirectoryContents, filter: Filter, on queue: OperationQueue) {
        let resourceValues = try! file.resourceValues(forKeys: keys)

        let isRegularFile = resourceValues.isRegularFile!
        let isReadable = resourceValues.isReadable!
        let isHidden = resourceValues.isHidden!

        guard isRegularFile && isReadable else {
            let path = file.absoluteURL.path(percentEncoded: false)
            print("\(path): not a readable file")
            return
        }

        switch filter {
            case .include(extensions: let extensions):
                guard extensions.contains(where: { $0.caseInsensitiveCompare(file.pathExtension) == .orderedSame } ) else { return }

            case .exclude(extensions: let extensions):
                guard !extensions.contains(where: { $0.caseInsensitiveCompare(file.pathExtension) == .orderedSame } ) else { return }

            case .all(includeHidden: let includeHidden):
                if isHidden && !includeHidden { return }
        }

        queue.addOperation { [weak self, weak directoryContents] in
            guard self != nil else { return }
            guard let directoryContents else { return }

            if "mp3".caseInsensitiveCompare(file.pathExtension) == .orderedSame,
               let tagInfo = TagInfo.getTagInfo(for: file) {
                directoryContents.add(mp3: file, tagInfo: tagInfo)
            } else {
                directoryContents.add(other: file)
            }
        }
    }

    private let fileManager = FileManager()
    private let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .isRegularFileKey, .isReadableKey, .isExecutableKey, .isHiddenKey]
    private let recursive: Bool
    private let singleThreaded: Bool
}

// MARK: - Type definitions

extension FileOperations {
    enum Filter {
        case include(extensions: [String])
        case exclude(extensions: [String])
        case all(includeHidden: Bool)
    }
}

extension FileOperations.Filter {
    static let `default` = Self.include(extensions: ["mp3"])
}

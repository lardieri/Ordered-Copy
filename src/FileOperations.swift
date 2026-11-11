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

    private let fileManager = FileManager()
    private let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .isRegularFileKey, .isReadableKey, .isWritableKey, .isExecutableKey, .isHiddenKey]
    private let recursive: Bool
    private let singleThreaded: Bool
}

// MARK: - Filters

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

// MARK: - Scanner

extension FileOperations {
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
                print("Error: \(path) is not a readable directory.")
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
                let isPackage = resourceValues.isPackage!
                let isFile = resourceValues.isRegularFile!
                let isReadable = resourceValues.isReadable!
                let isExecutable = resourceValues.isExecutable!

                if recursive && isDirectory && !isPackage && isReadable && isExecutable {
                    add(subdirectory: item, to: directoryContents, filter: filter, on: queue)
                } else if isFile && isReadable {
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
        queue.addOperation { [weak self, weak directoryContents] in
            guard let self else { return }
            guard let directoryContents else { return }

            if let subdirectoryContents = self.getDirectoryContents(of: subdirectory, filter: filter, on: queue) {
                directoryContents.add(subdirectory: subdirectory, contents: subdirectoryContents)
            }
        }
    }

    private func add(file: URL, to directoryContents: DirectoryContents, filter: Filter, on queue: OperationQueue) {
        switch filter {
            case .include(extensions: let extensions):
                guard extensions.contains(where: { $0.caseInsensitiveCompare(file.pathExtension) == .orderedSame } ) else { return }

            case .exclude(extensions: let extensions):
                guard !extensions.contains(where: { $0.caseInsensitiveCompare(file.pathExtension) == .orderedSame } ) else { return }

            case .all(includeHidden: let includeHidden):
                let isHidden = try! file.resourceValues(forKeys: keys).isHidden!
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
}

// MARK: - Alternate scanner

extension FileOperations {
    func enumerate(directory: URL, filter: Filter) -> DirectoryContents? {
        let includeHidden = if case .all(let includeHidden) = filter { includeHidden } else { false }
        let options: FileManager.DirectoryEnumerationOptions = if includeHidden {
            [.skipsPackageDescendants, .includesDirectoriesPostOrder]
        } else {
            [.skipsPackageDescendants, .includesDirectoriesPostOrder, .skipsHiddenFiles]
        }

        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: options)!

        let path = directory.absoluteURL.path(percentEncoded: false)
        var contentsStack = [DirectoryContents(path: path)]

        for case let url as URL in enumerator {
            guard let resourceValues = try? url.resourceValues(forKeys: keys) else {
                continue
            }

            let isDirectory = resourceValues.isDirectory!

            if isDirectory {
                // Subdirectory, not file.
                let reachedEndOfDirectory = isDirectory && enumerator.isEnumeratingDirectoryPostOrder

                if reachedEndOfDirectory {
                    // Finished a subdirectory.
                    let subdirectoryContents = contentsStack.removeLast()
                    if recursive {
                        contentsStack.last!.add(subdirectory: url, contents: subdirectoryContents)
                    }
                } else {
                    // Starting a new subdirectory.
                    let path = url.absoluteURL.path(percentEncoded: false)
                    contentsStack.append(DirectoryContents(path: path))
                }
            } else {
                // File, not subdirectory.
                if "mp3".caseInsensitiveCompare(url.pathExtension) == .orderedSame,
                   let tagInfo = TagInfo.getTagInfo(for: url) {
                    contentsStack.last!.add(mp3: url, tagInfo: tagInfo)
                } else {
                    contentsStack.last!.add(other: url)
                }
            }
        }

        assert(contentsStack.count == 1)
        return contentsStack.first!
    }
}

// MARK: - Copying

extension FileOperations {
    func copyDirectory(directoryContents: DirectoryContents, to destinationDirectory: URL) {
        assert(destinationDirectory.hasDirectoryPath)
        create(directory: destinationDirectory)

        for file in directoryContents.sortedMP3Files() {
            copy(item: file)
        }

        for file in directoryContents.sortedOtherFiles() {
            copy(item: file)
        }

        for subdirectory in directoryContents.sortedSubdirectories() {
            let destinationSubdirectory = destination(for: subdirectory.url, in: destinationDirectory)
            copyDirectory(directoryContents: subdirectory.contents, to: destinationSubdirectory)
        }

        func copy(item: DirectoryContents.ContentItem) {
            let source = item.url
            let destination = destination(for: source, in: destinationDirectory)

            let sourcePath = source.path(percentEncoded: false)
            let destinationPath = destination.path(percentEncoded: false)
            print("copying \(sourcePath) to \(destinationPath)")

            do {
                try? fileManager.removeItem(at: destination)
                try fileManager.copyItem(at: source, to: destination)
            } catch {
                let message = error.localizedDescription
                print("Error copying \(sourcePath) to \(destinationPath): \(message)")
                return
            }
        }
    }

    private func destination(for source: URL, in destinationDirectory: URL) -> URL {
        assert(destinationDirectory.hasDirectoryPath)
        let sourceName = source.lastPathComponent
        let directoryHint: URL.DirectoryHint = source.hasDirectoryPath ? .isDirectory : .notDirectory
        let destination = URL(filePath: sourceName, directoryHint: directoryHint, relativeTo: destinationDirectory).absoluteURL
        return destination
    }

    private func create(directory: URL) {
        assert(directory.hasDirectoryPath)
        let path = directory.path(percentEncoded: false)

        do {
            switch fileManager.exists(directory) {
                case .none:
                    print("Creating directory \(path)")
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                    fallthrough

                case .directory:
                    let writeableKeys = keys.union([.isWritableKey])
                    let resourceValues = try directory.resourceValues(forKeys: writeableKeys)

                    let isDirectory = resourceValues.isDirectory!
                    let isPackage = resourceValues.isPackage!
                    let isWritable = resourceValues.isWritable!
                    let isExecutable = resourceValues.isExecutable!

                    guard isDirectory && !isPackage && isWritable && isExecutable else {
                        throw CocoaError(
                            .fileWriteFileExists, userInfo: [
                                NSURLErrorKey: directory,
                                NSFilePathErrorKey: directory.path(percentEncoded: false),
                                NSLocalizedDescriptionKey: "Directory exists but is not writable."
                            ]
                        )
                    }

                case .file:
                    throw CocoaError(
                        .fileWriteFileExists, userInfo: [
                            NSURLErrorKey: directory,
                            NSFilePathErrorKey: path,
                            NSLocalizedDescriptionKey: "A file by that name already exists."
                        ]
                    )

            }
        } catch {
            let errorMessage = error.localizedDescription
            print("Error creating \(path): \(errorMessage)")
            return
        }
    }
}

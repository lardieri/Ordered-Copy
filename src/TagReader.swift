//
//  TagReader.swift
//  Ordered Copy
//
//  Copyright © 2026 Stephen Lardieri. All rights reserved.
//

import Foundation
import ID3TagEditor

struct TagInfo {
    let album: String?
    let artist: String?
    let title: String?
    let track: Int?
}

fileprivate let id3TagEditor = ID3TagEditor()

extension TagInfo {
    static func getTagInfo(for url: URL) -> TagInfo? {
        do {
            // A failed read (file doesn't exist, is not an MP3, is a corrupt MP3) throws.
            // A successful read of a valid MP3 file that has no ID3 tag returns nil.
            guard let id3Tag = try id3TagEditor.read(from: url) else {
                return nil
            }

            let tagContentReader = ID3TagContentReader(id3Tag: id3Tag)
            let album = tagContentReader.album()?.trimmingCharacters(in: .whitespacesAndNewlines)
            let artist = tagContentReader.artist()?.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = tagContentReader.title()?.trimmingCharacters(in: .whitespacesAndNewlines)
            let track = tagContentReader.trackPosition()?.position

            return TagInfo(album: album, artist: artist, title: title, track: track)
        } catch {
            let errorMessage = error.localizedDescription
            print("Error reading ID3 tag from \(url.lastPathComponent): \(errorMessage)")
            return nil
        }
    }
}

extension TagInfo: CustomStringConvertible {
    var description: String {
        let album = self.album.flatMap { "Album: \($0)" }
        let artist = self.artist.flatMap { "Artist: \($0)" }
        let title = self.title.flatMap { "Title: \($0)" }
        let track = self.track.flatMap { "Track: \($0)" }

        let description = [album, artist, title, track].compactMap(\.self).joined(separator: "\n")

        return description
    }
}

extension ID3TagEditorError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
            case .invalidFileFormat: "Invalid file format"
            case .tagTooBig: "ID3 tag too big"
            case .invalidTagData: "Invalid ID3 tag data"
            case .corruptedFile: "Corrupted file"
        }
    }
}

//
//  TagReader.swift
//  Ordered Copy
//
//  Copyright © 2026 Stephen Lardieri. All rights reserved.
//

import Foundation
import ID3TagEditor

struct TagInfo {
    let track: Int?
    let title: String?
    let album: String?
    let artist: String?
}

fileprivate let id3TagEditor = ID3TagEditor()

extension TagInfo {
    static func getTagInfo(for url: URL) -> TagInfo? {
        do {
#if false // Pending PR submitted to upstream repo.

            // A failed read (file doesn't exist, is not an MP3, is a corrupt MP3) throws.
            // A successful read of a valid MP3 file that has no ID3 tag returns nil.
            guard let id3Tag = try id3TagEditor.read(from: url) else {
                return nil
            }

#else

            // A failed read (file doesn't exist, is not an MP3, is a corrupt MP3) throws.
            // A successful read of a valid MP3 file that has no ID3 tag returns nil.
            let path = url.absoluteURL.path(percentEncoded: false)
            guard let id3Tag = try id3TagEditor.read(from: path) else {
                return nil
            }

#endif

            let tagContentReader = ID3TagContentReader(id3Tag: id3Tag)
            let title = tagContentReader.title()
            let artist = tagContentReader.artist()
            let album = tagContentReader.album()
            let track = tagContentReader.trackPosition()?.position

            return TagInfo(track: track, title: title, album: album, artist: artist)
        } catch {
            let errorMessage = error.localizedDescription
            print("Error reading ID3 tag from \(url.lastPathComponent): \(errorMessage)")
            return nil
        }
    }
}

extension TagInfo: CustomStringConvertible {
    var description: String {
        let title = self.title.flatMap { "Title: \($0)" }
        let album = self.album.flatMap { "Album: \($0)" }
        let artist = self.artist.flatMap { "Artist: \($0)" }
        let track = self.track.flatMap { "Track: \($0)" }

        let description = [title, album, artist, track].compactMap(\.self).joined(separator: "\n")

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

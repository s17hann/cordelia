import Foundation
import SwiftData

@Model
final class Item {
    var title: String
    var artist: String
    var album: String
    var fileName: String
    var artworkData: Data?
    var playCount: Int
    var lastPlayedDate: Date?
    var isrc: String?

    init(title: String, artist: String, album: String, fileName: String, artworkData: Data? = nil, playCount: Int = 0, lastPlayedDate: Date? = nil, isrc: String? = nil) {
        self.title = title
        self.artist = artist
        self.album = album
        self.fileName = fileName
        self.artworkData = artworkData
        self.playCount = playCount
        self.lastPlayedDate = lastPlayedDate
        self.isrc = isrc
    }
}

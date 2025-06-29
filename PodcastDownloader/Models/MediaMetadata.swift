//
//  MediaMetadata.swift
//  PodcastDownloader
//
//  Created by Mansour Kalagar on 28.06.25.
//

import Foundation

struct MediaMetadata {
    let title: String
    let showOrChannel: String?
    let duration: TimeInterval?
    let publishDate: Date?
    let description: String?
    let tags: [String]
    let artworkURL: String?
    let hasVideo: Bool
    let originalURL: String
    let sourceProvider: SourceProvider
    
    init(
        title: String,
        showOrChannel: String? = nil,
        duration: TimeInterval? = nil,
        publishDate: Date? = nil,
        description: String? = nil,
        tags: [String] = [],
        artworkURL: String? = nil,
        hasVideo: Bool = false,
        originalURL: String,
        sourceProvider: SourceProvider
    ) {
        self.title = title
        self.showOrChannel = showOrChannel
        self.duration = duration
        self.publishDate = publishDate
        self.description = description
        self.tags = tags
        self.artworkURL = artworkURL
        self.hasVideo = hasVideo
        self.originalURL = originalURL
        self.sourceProvider = sourceProvider
    }
}

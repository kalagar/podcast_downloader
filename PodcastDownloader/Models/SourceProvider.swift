//
//  SourceProvider.swift
//  PodcastDownloader
//
//  Created by Mansour Kalagar on 28.06.25.
//

import Foundation
import SwiftUI

enum SourceProvider: String, CaseIterable {
    case youtube = "YouTube"
    case spotify = "Spotify"
    case rss = "RSS"
    case unknown = "Unknown"
    
    var displayName: String {
        return rawValue
    }
    
    var iconName: String {
        switch self {
        case .youtube:
            return "play.rectangle.fill"
        case .spotify:
            return "music.note"
        case .rss:
            return "antenna.radiowaves.left.and.right"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .youtube:
            return .red
        case .spotify:
            return .green
        case .rss:
            return .orange
        case .unknown:
            return .gray
        }
    }
    
    static func detectProvider(from url: String) -> SourceProvider {
        let lowercased = url.lowercased()
        
        if lowercased.contains("youtube.com") || lowercased.contains("youtu.be") {
            return .youtube
        } else if lowercased.contains("spotify.com") {
            return .spotify
        } else if lowercased.hasSuffix(".xml") || lowercased.contains("rss") || lowercased.contains("feed") {
            return .rss
        } else {
            return .unknown
        }
    }
}

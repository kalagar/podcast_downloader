//
//  MetadataExtractor.swift
//  PodcastDownloader
//
//  Created by AI Assistant on 6/28/25.
//

import Foundation
import Combine

/// Extracts metadata from various media sources
@MainActor
class MetadataExtractor: ObservableObject {
    
    private let session = URLSession.shared
    
    /// Extract metadata from a URL
    func extractMetadata(from url: String) async throws -> MediaMetadata {
        let provider = SourceProvider.detectProvider(from: url)
        
        switch provider {
        case .youtube:
            return try await extractYouTubeMetadata(from: url)
        case .spotify:
            return try await extractSpotifyMetadata(from: url)
        case .rss:
            return try await extractRSSMetadata(from: url)
        case .unknown:
            return try await extractGenericMetadata(from: url)
        }
    }
    
    // MARK: - YouTube Metadata
    
    private func extractYouTubeMetadata(from url: String) async throws -> MediaMetadata {
        let ytDlpPath = "/opt/homebrew/bin/yt-dlp"
        
        // Use yt-dlp to extract metadata without downloading
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.arguments = [
            "--dump-json",
            "--no-playlist",
            url
        ]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AppError.metadataExtractionFailed("yt-dlp metadata extraction failed: \(errorString)")
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let jsonString = String(data: outputData, encoding: .utf8),
              let jsonData = jsonString.data(using: .utf8) else {
            throw AppError.metadataExtractionFailed("Invalid JSON response from yt-dlp")
        }
        
        // Parse yt-dlp JSON response
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw AppError.metadataExtractionFailed("Failed to parse yt-dlp JSON")
        }
        
        let title = json["title"] as? String ?? "Unknown Title"
        let channel = json["uploader"] as? String ?? json["channel"] as? String ?? "Unknown Channel"
        let duration = json["duration"] as? Double ?? 0.0
        let description = json["description"] as? String ?? ""
        let uploadDate = json["upload_date"] as? String
        let tags = json["tags"] as? [String] ?? []
        let thumbnail = json["thumbnail"] as? String
        
        // Parse upload date (format: YYYYMMDD)
        var publishDate = Date()
        if let uploadDate = uploadDate, uploadDate.count == 8 {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            publishDate = formatter.date(from: uploadDate) ?? Date()
        }
        
        return MediaMetadata(
            title: title,
            showOrChannel: channel,
            duration: duration,
            publishDate: publishDate,
            description: description,
            tags: tags + ["youtube", "video"],
            artworkURL: thumbnail,
            hasVideo: true,
            originalURL: url,
            sourceProvider: .youtube
        )
    }
    
    private func extractYouTubeVideoId(from url: String) -> String {
        // Extract video ID from various YouTube URL formats
        if let components = URLComponents(string: url) {
            // youtube.com/watch?v=VIDEO_ID
            if let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value {
                return videoId
            }
            // youtu.be/VIDEO_ID
            if components.host?.contains("youtu.be") == true {
                return String(components.path.dropFirst()) // Remove leading "/"
            }
        }
        
        // Fallback: extract alphanumeric ID from URL
        let pattern = "[a-zA-Z0-9_-]{11}"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: url, options: [], range: NSRange(location: 0, length: url.count)) {
            return String(url[Range(match.range, in: url)!])
        }
        
        return "unknown"
    }
    
    // MARK: - Spotify Metadata
    
    private func extractSpotifyMetadata(from url: String) async throws -> MediaMetadata {
        // Extract episode/show ID from Spotify URL
        let episodeId = extractSpotifyEpisodeId(from: url)
        
        // In a real implementation, we would use Spotify Web API
        // For now, simulate the response
        let title = "Sample Spotify Episode \(episodeId)"
        let show = "Sample Podcast Show"
        let duration = 1800.0 // 30 minutes
        let publishDate = Date().addingTimeInterval(-86400 * 3) // 3 days ago
        
        return MediaMetadata(
            title: title,
            showOrChannel: show,
            duration: duration,
            publishDate: publishDate,
            description: "This is a sample Spotify podcast episode description. In a real implementation, this would be fetched using the Spotify Web API.",
            tags: ["spotify", "podcast", "audio"],
            artworkURL: nil,
            hasVideo: false,
            originalURL: url,
            sourceProvider: .spotify
        )
    }
    
    private func extractSpotifyEpisodeId(from url: String) -> String {
        // Extract episode ID from Spotify URL: https://open.spotify.com/episode/ID
        guard let components = URLComponents(string: url) else { return "unknown" }
        let pathComponents = components.path.components(separatedBy: "/")
        
        if pathComponents.count >= 3, pathComponents[1] == "episode" {
            return pathComponents[2]
        }
        return "unknown"
    }
    
    // MARK: - RSS Metadata
    
    private func extractRSSMetadata(from url: String) async throws -> MediaMetadata {
        let (data, _) = try await session.data(from: URL(string: url)!)
        
        // Parse RSS/Atom feed
        let parser = RSSParser()
        let feedData = try parser.parseFeed(data)
        
        // For RSS, we might be dealing with a specific episode URL or a feed URL
        // For simplicity, we'll extract info from the first item in the feed
        guard let item = feedData.items.first else {
            throw AppError.metadataExtractionFailed("No items found in RSS feed")
        }
        
        return MediaMetadata(
            title: item.title ?? "Untitled Episode",
            showOrChannel: feedData.title ?? "Unknown Podcast",
            duration: item.duration ?? 0,
            publishDate: item.publishDate ?? Date(),
            description: item.description ?? "",
            tags: ["rss", "podcast", "audio"],
            artworkURL: item.artworkURL ?? feedData.artworkURL,
            hasVideo: false,
            originalURL: item.enclosureURL ?? url,
            sourceProvider: .rss
        )
    }
    
    // MARK: - Generic Metadata
    
    private func extractGenericMetadata(from url: String) async throws -> MediaMetadata {
        guard let mediaURL = URL(string: url) else {
            throw AppError.invalidURL(url)
        }
        
        // Try to get basic info from HTTP headers
        var request = URLRequest(url: mediaURL)
        request.httpMethod = "HEAD"
        let (_, response) = try await session.data(for: request)
        
        let httpResponse = response as? HTTPURLResponse
        let contentType = httpResponse?.value(forHTTPHeaderField: "Content-Type") ?? ""
        let contentLength = httpResponse?.value(forHTTPHeaderField: "Content-Length")
            .flatMap { Int64($0) } ?? 0
        
        // Extract filename from URL
        let filename = mediaURL.lastPathComponent
        let title = filename.isEmpty ? "Unknown Media" : filename
        
        // Determine if it's audio or video based on content type
        let isVideo = contentType.contains("video")
        let tags = isVideo ? ["video", "direct"] : ["audio", "direct"]
        
        return MediaMetadata(
            title: title,
            showOrChannel: "Unknown",
            duration: 0, // Can't determine without downloading
            publishDate: Date(),
            description: "Direct media file",
            tags: tags,
            artworkURL: nil,
            hasVideo: isVideo,
            originalURL: url,
            sourceProvider: .unknown
        )
    }
}

// MARK: - RSS Parser

private struct RSSParser {
    struct FeedData {
        let title: String?
        let description: String?
        let artworkURL: String?
        let items: [ItemData]
    }
    
    struct ItemData {
        let title: String?
        let description: String?
        let publishDate: Date?
        let duration: TimeInterval?
        let artworkURL: String?
        let enclosureURL: String?
    }
    
    func parseFeed(_ data: Data) throws -> FeedData {
        // Simple RSS/Atom parser
        // In a real implementation, you'd use XMLParser or a dedicated RSS library
        
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw AppError.metadataExtractionFailed("Invalid XML data")
        }
        
        // Very basic parsing - in reality you'd use a proper XML parser
        let title = extractTextBetween(xmlString, start: "<title>", end: "</title>") ?? "Unknown Feed"
        let description = extractTextBetween(xmlString, start: "<description>", end: "</description>")
        
        // Parse first item for simplicity
        let item = ItemData(
            title: extractTextBetween(xmlString, start: "<item><title>", end: "</title>") ??
                   extractTextBetween(xmlString, start: "<entry><title>", end: "</title>"),
            description: extractTextBetween(xmlString, start: "<item><description>", end: "</description>") ??
                        extractTextBetween(xmlString, start: "<entry><summary>", end: "</summary>"),
            publishDate: Date(), // Would parse from pubDate/published
            duration: nil, // Would parse from iTunes duration or other fields
            artworkURL: nil, // Would extract from enclosure or iTunes image
            enclosureURL: extractEnclosureURL(from: xmlString)
        )
        
        return FeedData(
            title: title,
            description: description,
            artworkURL: nil,
            items: [item]
        )
    }
    
    private func extractTextBetween(_ text: String, start: String, end: String) -> String? {
        guard let startRange = text.range(of: start),
              let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) else {
            return nil
        }
        
        return String(text[startRange.upperBound..<endRange.lowerBound])
    }
    
    private func extractEnclosureURL(from xml: String) -> String? {
        // Look for enclosure tag: <enclosure url="..." type="..." length="..."/>
        let pattern = #"<enclosure[^>]+url="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: xml, options: [], range: NSRange(location: 0, length: xml.count)),
              let range = Range(match.range(at: 1), in: xml) else {
            return nil
        }
        
        return String(xml[range])
    }
}

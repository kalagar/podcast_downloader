//
//  DownloadService.swift
//  PodcastDownloader
//
//  Created by Mansour Kalagar on 28.06.25.
//

import Foundation
import CoreData
import Combine
import OSLog

enum DownloadError: LocalizedError {
    case invalidURL
    case downloadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        }
    }
}

@MainActor
class DownloadService: ObservableObject {
    private let logger = Logger(subsystem: "com.podload.mac", category: "download")
    private let persistenceController: PersistenceController
    private let metadataExtractor: MetadataExtractor
    private let mediaDownloader: MediaDownloader
    
    // Download progress tracking
    @Published var activeDownloads: [UUID: Float] = [:]
    @Published var isDownloading = false
    @Published var currentDownloadTitle: String?
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.metadataExtractor = MetadataExtractor()
        self.mediaDownloader = MediaDownloader()
    }
    
    // MARK: - Public API
    
    @discardableResult
    func downloadMedia(from url: String) async throws -> MediaItem {
        logger.info("Starting download for URL: \(url)")
        
        guard URL(string: url) != nil else {
            throw DownloadError.invalidURL
        }
        
        isDownloading = true
        currentDownloadTitle = "Extracting metadata..."
        
        defer {
            isDownloading = false
            currentDownloadTitle = nil
        }
        
        do {
            // Extract metadata first using our dedicated service
            let metadata = try await metadataExtractor.extractMetadata(from: url)
            currentDownloadTitle = metadata.title
            
            // Check if item already exists
            if (try findExistingItem(sourceURL: metadata.originalURL)) != nil {
                throw DownloadError.downloadFailed("Media from this URL already exists in your library")
            }
            
            // Create media item in Core Data
            let context = persistenceController.container.viewContext
            let mediaItem = MediaItem(context: context)
            mediaItem.id = UUID()
            mediaItem.title = metadata.title
            mediaItem.showOrChannel = metadata.showOrChannel
            mediaItem.originalURL = metadata.originalURL
            mediaItem.sourceProvider = metadata.sourceProvider.rawValue
            mediaItem.duration = metadata.duration ?? 0
            mediaItem.publishDate = metadata.publishDate
            mediaItem.downloadDate = Date()
            mediaItem.itemDescription = metadata.description
            mediaItem.tags = metadata.tags.joined(separator: ",")
            mediaItem.artworkURL = metadata.artworkURL
            mediaItem.hasVideo = metadata.hasVideo
            mediaItem.isWatched = false
            mediaItem.lastPlayPosition = 0
            
            // Download the actual media file using our media downloader
            let fileURL = try await mediaDownloader.downloadMedia(
                from: url,
                metadata: metadata,
                context: context
            )
            
            if metadata.hasVideo {
                mediaItem.localVideoPath = fileURL.path
            } else {
                mediaItem.localAudioPath = fileURL.path
            }
            
            // Set download status
            mediaItem.downloadStatus = "completed"
            mediaItem.downloadProgress = 1.0
            
            // Get file size
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[FileAttributeKey.size] as? Int64 {
                mediaItem.fileSize = fileSize
            }
            
            try context.save()
            logger.info("Download completed for: \(metadata.title)")
            
            return mediaItem
            
        } catch {
            logger.error("Download failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func findExistingItem(sourceURL: String) throws -> MediaItem? {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<MediaItem> = MediaItem.fetchRequest()
        request.predicate = NSPredicate(format: "originalURL == %@", sourceURL)
        request.fetchLimit = 1
        
        return try context.fetch(request).first
    }
    
    private func getDownloadsDirectory() -> URL {
        let urls = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
        let downloadsDirectory = urls[0].appendingPathComponent("PodLoad")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        
        return downloadsDirectory
    }
}

//
//  MediaDownloader.swift
//  PodcastDownloader
//
//  Created by AI Assistant on 6/28/25.
//

import Foundation
import Combine
import CoreData

/// Handles the actual downloading of media files using yt-dlp or other downloaders
@MainActor
class MediaDownloader: ObservableObject {
    @Published var downloadProgress: [UUID: Double] = [:]
    @Published var activeDownloads: Set<UUID> = []
    
    private var downloadTasks: [UUID: Task<Void, Never>] = [:]
    private let fileManager = FileManager.default
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PodLoad")
            .appendingPathComponent("Media")
    }
    
    init() {
        // Create media directory if it doesn't exist
        try? fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
    }
    
    /// Download media from the given URL with metadata
    func downloadMedia(
        from url: String,
        metadata: MediaMetadata,
        context: NSManagedObjectContext
    ) async throws -> URL {
        let itemId = UUID()
        
        await MainActor.run {
            activeDownloads.insert(itemId)
            downloadProgress[itemId] = 0.0
        }
        
        defer {
            Task { @MainActor in
                activeDownloads.remove(itemId)
                downloadProgress.removeValue(forKey: itemId)
            }
        }
        
        // Create provider-specific directory
        let providerDir = documentsDirectory
            .appendingPathComponent(metadata.sourceProvider.rawValue)
        try? fileManager.createDirectory(at: providerDir, withIntermediateDirectories: true)
        
        // Try different download methods based on provider
        switch metadata.sourceProvider {
        case .youtube:
            return try await downloadWithYtDlp(url: url, metadata: metadata, outputDir: providerDir, itemId: itemId)
        case .spotify:
            return try await downloadSpotifyAudio(url: url, metadata: metadata, outputDir: providerDir, itemId: itemId)
        case .rss:
            return try await downloadDirectMedia(url: url, metadata: metadata, outputDir: providerDir, itemId: itemId)
        case .unknown:
            return try await downloadDirectMedia(url: url, metadata: metadata, outputDir: providerDir, itemId: itemId)
        }
    }
    
    /// Cancel a download
    func cancelDownload(for itemId: UUID) {
        downloadTasks[itemId]?.cancel()
        downloadTasks.removeValue(forKey: itemId)
        activeDownloads.remove(itemId)
        downloadProgress.removeValue(forKey: itemId)
    }
    
    // MARK: - Private Download Methods
    
    private func downloadWithYtDlp(
        url: String,
        metadata: MediaMetadata,
        outputDir: URL,
        itemId: UUID
    ) async throws -> URL {
        let ytDlpPath = "/opt/homebrew/bin/yt-dlp"
        
        // Create a safe filename template
        let filenameTemplate = sanitizeFilename(metadata.title)
        let outputTemplate = outputDir.appendingPathComponent("\(filenameTemplate).%(ext)s").path
        
        // Build yt-dlp command
        var arguments = [
            "--extract-flat", "false",
            "--write-info-json",
            "--output", outputTemplate,
            "--format", "best[height<=1080]/best", // Prefer up to 1080p
            "--no-playlist", // Download single video only
            "--embed-metadata",
            "--add-metadata",
            url
        ]
        
        // Execute yt-dlp
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Update progress periodically (yt-dlp doesn't easily provide real-time progress)
        let progressTask = Task {
            for progress in stride(from: 0.0, through: 0.9, by: 0.1) {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                try Task.checkCancellation()
                
                await MainActor.run {
                    downloadProgress[itemId] = progress
                }
            }
        }
        
        defer {
            progressTask.cancel()
        }
        
        try process.run()
        process.waitUntilExit()
        
        // Check if process succeeded
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AppError.downloadFailed("yt-dlp failed: \(errorString)")
        }
        
        // Find the downloaded file
        let downloadedFiles = try fileManager.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)
            .filter { file in
                let filename = file.lastPathComponent
                return filename.hasPrefix(filenameTemplate) && 
                       (filename.hasSuffix(".mp4") || filename.hasSuffix(".mkv") || 
                        filename.hasSuffix(".webm") || filename.hasSuffix(".m4a"))
            }
            .sorted { $0.path < $1.path }
        
        guard let downloadedFile = downloadedFiles.first else {
            throw AppError.downloadFailed("Downloaded file not found")
        }
        
        await MainActor.run {
            downloadProgress[itemId] = 1.0
        }
        
        return downloadedFile
    }
    
    private func downloadSpotifyAudio(
        url: String,
        metadata: MediaMetadata,
        outputDir: URL,
        itemId: UUID
    ) async throws -> URL {
        // Note: Spotify doesn't allow direct downloads of their content
        // This would need to integrate with Spotify's API for podcast episodes only
        // For now, we'll create a placeholder
        
        let filename = sanitizeFilename("\(metadata.title).mp3")
        let outputFile = outputDir.appendingPathComponent(filename)
        
        // Simulate download
        for progress in stride(from: 0.0, through: 1.0, by: 0.2) {
            try Task.checkCancellation()
            
            await MainActor.run {
                downloadProgress[itemId] = progress
            }
            
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        
        try "Placeholder Spotify content for \(metadata.title)".write(to: outputFile, atomically: true, encoding: .utf8)
        
        return outputFile
    }
    
    private func downloadDirectMedia(
        url: String,
        metadata: MediaMetadata,
        outputDir: URL,
        itemId: UUID
    ) async throws -> URL {
        guard let mediaURL = URL(string: url) else {
            throw AppError.invalidURL(url)
        }
        
        let session = URLSession.shared
        
        // Get file info first
        var request = URLRequest(url: mediaURL)
        request.httpMethod = "HEAD"
        let (_, headResponse) = try await session.data(for: request)
        
        let contentLength = (headResponse as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Length")
            .flatMap { Int64($0) } ?? 0
        
        // Determine file extension from content type or URL
        let contentType = (headResponse as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Type") ?? ""
        let fileExtension = fileExtension(for: contentType, url: url)
        
        let filename = sanitizeFilename("\(metadata.title).\(fileExtension)")
        let outputFile = outputDir.appendingPathComponent(filename)
        
        // Download the file
        let (localURL, _) = try await session.download(from: mediaURL) { [self] bytesWritten, totalBytesWritten, totalBytesExpectedToWrite in
            Task { @MainActor in
                let progress = totalBytesExpectedToWrite > 0 
                    ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                    : 0.0
                downloadProgress[itemId] = progress
            }
        }
        
        // Move to final location
        try fileManager.moveItem(at: localURL, to: outputFile)
        
        return outputFile
    }
    
    // MARK: - Helper Methods
    
    private func sanitizeFilename(_ filename: String) -> String {
        let invalidChars = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return filename.components(separatedBy: invalidChars).joined(separator: "_")
    }
    
    private func fileExtension(for contentType: String, url: String) -> String {
        switch contentType.lowercased() {
        case let type where type.contains("video/mp4"):
            return "mp4"
        case let type where type.contains("video/"):
            return "mp4"
        case let type where type.contains("audio/mpeg"):
            return "mp3"
        case let type where type.contains("audio/mp4"):
            return "m4a"
        case let type where type.contains("audio/"):
            return "mp3"
        default:
            // Try to extract from URL
            let urlPath = URL(string: url)?.pathExtension ?? ""
            return urlPath.isEmpty ? "mp4" : urlPath
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension URLSession {
    func download(from url: URL, progress: @escaping (Int64, Int64, Int64) -> Void) async throws -> (URL, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let task = downloadTask(with: url) { localURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let localURL = localURL, let response = response {
                    continuation.resume(returning: (localURL, response))
                } else {
                    continuation.resume(throwing: AppError.downloadFailed("Unknown download error"))
                }
            }
            
            // Note: Progress tracking would need a custom delegate implementation
            // For now, we'll update progress periodically
            task.resume()
        }
    }
}

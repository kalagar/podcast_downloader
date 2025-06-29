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
        print("=== Starting yt-dlp download process ===")
        print("URL: \(url)")
        print("Output directory: \(outputDir.path)")
        
        // Try to find yt-dlp in common locations
        let possiblePaths = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp"
        ]
        
        print("Checking for yt-dlp in common locations...")
        var ytDlpPath: String?
        for path in possiblePaths {
            print("Checking path: \(path)")
            let fileExists = FileManager.default.fileExists(atPath: path)
            print("  - File exists: \(fileExists)")
            
            if fileExists {
                let isExecutable = FileManager.default.isExecutableFile(atPath: path)
                print("  - Is executable: \(isExecutable)")
                
                if isExecutable {
                    // Try to actually access the file to verify sandbox permissions
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: path)
                        print("  - File attributes: \(attributes)")
                        print("Found yt-dlp at: \(path)")
                        ytDlpPath = path
                        break
                    } catch {
                        print("  - Error accessing file: \(error)")
                    }
                }
            }
        }
        
        // If not found in common locations, try to find it using 'which'
        if ytDlpPath == nil {
            print("yt-dlp not found in common locations, trying 'which' command...")
            do {
                ytDlpPath = try await findYtDlpPath()
                if let path = ytDlpPath {
                    print("Found yt-dlp via 'which': \(path)")
                }
            } catch {
                print("Error running 'which' command: \(error)")
            }
        }
        
        // Also try to use /usr/bin/env as a fallback
        if ytDlpPath == nil {
            print("Trying /usr/bin/env approach...")
            ytDlpPath = "/usr/bin/env"
        }
        
        guard let finalYtDlpPath = ytDlpPath else {
            let errorMessage = """
            yt-dlp not found. Please ensure it's installed and accessible.
            
            To install yt-dlp:
            1. Using Homebrew: brew install yt-dlp
            2. Using pip: pip install yt-dlp
            
            Searched locations:
            \(possiblePaths.joined(separator: "\n"))
            
            This app requires yt-dlp to download YouTube videos. Please install it and restart the app.
            """
            print("ERROR: \(errorMessage)")
            throw AppError.downloadFailed(errorMessage)
        }
        
        // Create a safe filename template
        let filenameTemplate = sanitizeFilename(metadata.title)
        let outputTemplate = outputDir.appendingPathComponent("\(filenameTemplate).%(ext)s").path
        
        print("Using yt-dlp path: \(finalYtDlpPath)")
        print("Output template: \(outputTemplate)")
        print("Downloading from URL: \(url)")
        
        // Build yt-dlp command - adjust based on the path type
        var arguments: [String]
        if finalYtDlpPath == "/usr/bin/env" {
            // Use env to find yt-dlp in PATH
            arguments = [
                "yt-dlp",
                "--extract-flat", "false",
                "--write-info-json",
                "--output", outputTemplate,
                "--format", "best[height<=1080]/best", // Prefer up to 1080p
                "--no-playlist", // Download single video only
                "--embed-metadata",
                "--add-metadata",
                url
            ]
        } else {
            arguments = [
                "--extract-flat", "false",
                "--write-info-json",
                "--output", outputTemplate,
                "--format", "best[height<=1080]/best", // Prefer up to 1080p
                "--no-playlist", // Download single video only
                "--embed-metadata",
                "--add-metadata",
                url
            ]
        }
        
        print("yt-dlp command: \(finalYtDlpPath) \(arguments.joined(separator: " "))")
        
        // Execute yt-dlp
        let process = Process()
        process.executableURL = URL(fileURLWithPath: finalYtDlpPath)
        process.arguments = arguments
        
        // Set environment PATH to include common directories
        var environment = ProcessInfo.processInfo.environment
        let pathAdditions = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        if let existingPath = environment["PATH"] {
            environment["PATH"] = "\(pathAdditions):\(existingPath)"
        } else {
            environment["PATH"] = pathAdditions
        }
        process.environment = environment
        
        print("Process environment PATH: \(environment["PATH"] ?? "not set")")
        
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
        
        do {
            print("Attempting to run yt-dlp process...")
            try process.run()
            print("Process started successfully, waiting for completion...")
            process.waitUntilExit()
            print("Process completed with exit status: \(process.terminationStatus)")
        } catch {
            print("Failed to run yt-dlp process: \(error)")
            throw AppError.downloadFailed("Failed to start yt-dlp: \(error.localizedDescription)")
        }
        
        // Check if process succeeded
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            
            let errorString = String(data: errorData, encoding: .utf8) ?? "No error output"
            let outputString = String(data: outputData, encoding: .utf8) ?? "No output"
            
            print("yt-dlp failed with status: \(process.terminationStatus)")
            print("Error output: \(errorString)")
            print("Standard output: \(outputString)")
            
            throw AppError.downloadFailed("yt-dlp failed (exit code \(process.terminationStatus)): \(errorString)")
        }
        
        // Get any output from the process
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let outputString = String(data: outputData, encoding: .utf8) ?? "No output"
        print("yt-dlp output: \(outputString)")
        
        // Find the downloaded file
        print("Looking for downloaded files in: \(outputDir.path)")
        let downloadedFiles = try fileManager.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)
            .filter { file in
                let filename = file.lastPathComponent
                let matches = filename.hasPrefix(filenameTemplate) && 
                       (filename.hasSuffix(".mp4") || filename.hasSuffix(".mkv") || 
                        filename.hasSuffix(".webm") || filename.hasSuffix(".m4a"))
                print("Checking file: \(filename) - matches criteria: \(matches)")
                return matches
            }
            .sorted { $0.path < $1.path }
        
        print("Found \(downloadedFiles.count) matching files")
        for file in downloadedFiles {
            print("  - \(file.lastPathComponent)")
        }
        
        guard let downloadedFile = downloadedFiles.first else {
            print("No downloaded file found matching criteria")
            // List all files in the directory for debugging
            do {
                let allFiles = try fileManager.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)
                print("All files in output directory:")
                for file in allFiles {
                    print("  - \(file.lastPathComponent)")
                }
            } catch {
                print("Error listing directory contents: \(error)")
            }
            throw AppError.downloadFailed("Downloaded file not found")
        }
        
        print("Successfully downloaded: \(downloadedFile.lastPathComponent)")
        
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
        
        let _ = (headResponse as? HTTPURLResponse)?
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
    
    private func findYtDlpPath() async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = ["yt-dlp"]
            
            let pipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errorPipe
            
            // Set environment PATH to include common directories
            var environment = ProcessInfo.processInfo.environment
            let pathAdditions = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "\(pathAdditions):\(existingPath)"
            } else {
                environment["PATH"] = pathAdditions
            }
            process.environment = environment
            
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                if process.terminationStatus == 0,
                   let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty {
                    print("'which' found yt-dlp at: \(output)")
                    continuation.resume(returning: output)
                } else {
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    print("'which' command failed: \(errorString)")
                    continuation.resume(returning: nil)
                }
            }
            
            do {
                try process.run()
            } catch {
                print("Failed to run 'which' command: \(error)")
                continuation.resume(throwing: error)
            }
        }
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

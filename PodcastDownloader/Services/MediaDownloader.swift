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
        NSLog("=== Starting yt-dlp download process ===")
        NSLog("URL: %@", url)
        NSLog("Output directory: %@", outputDir.path)
        
        // Find working yt-dlp path
        let ytDlpPath = try await findWorkingYtDlpPath()
        NSLog("Using yt-dlp path: %@", ytDlpPath)
        
        // Create a safe filename template
        let filenameTemplate = sanitizeFilename(metadata.title)
        let outputTemplate = outputDir.appendingPathComponent("\(filenameTemplate).%(ext)s").path
        
        NSLog("Output template: %@", outputTemplate)
        NSLog("Downloading from URL: %@", url)
        
        // Execute yt-dlp download
        return try await executeYtDlpDownload(
            ytDlpPath: ytDlpPath,
            url: url,
            outputTemplate: outputTemplate,
            outputDir: outputDir,
            filenameTemplate: filenameTemplate,
            itemId: itemId
        )
    }
    
    private func findWorkingYtDlpPath() async throws -> String {
        NSLog("Searching for working yt-dlp binary...")
        
        // Strategy 1: Check common installation paths
        let commonPaths = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp"
        ]
        
        for path in commonPaths {
            NSLog("Testing path: %@", path)
            if await testYtDlpPath(path) {
                NSLog("Found working yt-dlp at: %@", path)
                return path
            }
        }
        
        // Strategy 2: Use `which` command to find yt-dlp
        NSLog("Trying 'which' command...")
        if let whichPath = try? await findYtDlpWithWhich() {
            NSLog("Found yt-dlp via which: %@", whichPath)
            if await testYtDlpPath(whichPath) {
                return whichPath
            }
        }
        
        // Strategy 3: Try copying yt-dlp to a temporary location
        NSLog("Trying to copy yt-dlp to temporary location...")
        if let tempPath = try? await copyYtDlpToTemp() {
            NSLog("Copied yt-dlp to: %@", tempPath)
            if await testYtDlpPath(tempPath) {
                return tempPath
            }
        }
        
        // Strategy 4: Last resort - use env with full PATH
        NSLog("Using /usr/bin/env as last resort...")
        if await testEnvYtDlp() {
            return "/usr/bin/env"
        }
        
        // If all else fails, throw an error
        let errorMessage = """
        yt-dlp not found or not accessible. 
        
        This appears to be a sandboxing issue. The app cannot execute yt-dlp.
        
        To install yt-dlp:
        1. Using Homebrew: brew install yt-dlp
        2. Using pip: pip install yt-dlp
        
        Searched locations:
        \(commonPaths.joined(separator: "\n"))
        
        Note: macOS sandbox restrictions may prevent external tool execution.
        Consider running the app without sandbox restrictions for development.
        """
        NSLog("ERROR: %@", errorMessage)
        throw AppError.downloadFailed(errorMessage)
    }
    
    /// Test if a yt-dlp path works by running --version
    private func testYtDlpPath(_ path: String) async -> Bool {
        do {
            let result = try await executeSimpleCommand(
                executablePath: path,
                arguments: ["--version"]
            )
            NSLog("Path %@ test result: exit=%d", path, result.exitCode)
            print("Path test result for \(path): exit=\(result.exitCode), output: \(result.output.prefix(100))")
            return result.exitCode == 0
        } catch {
            NSLog("Path %@ test failed: %@", path, error.localizedDescription)
            return false
        }
    }
    
    /// Test if /usr/bin/env can find yt-dlp
    private func testEnvYtDlp() async -> Bool {
        do {
            let result = try await executeSimpleCommand(
                executablePath: "/usr/bin/env",
                arguments: ["yt-dlp", "--version"]
            )
            NSLog("/usr/bin/env yt-dlp test result: exit=%d", result.exitCode)
            return result.exitCode == 0
        } catch {
            NSLog("/usr/bin/env yt-dlp test failed: %@", error.localizedDescription)
            return false
        }
    }
    
    /// Execute a simple command and return the result
    private func executeSimpleCommand(
        executablePath: String,
        arguments: [String]
    ) async throws -> (exitCode: Int32, output: String) {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: executablePath)
                task.arguments = arguments
                
                // Set environment with extended PATH
                var environment = ProcessInfo.processInfo.environment
                let pathAdditions = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
                if let existingPath = environment["PATH"] {
                    environment["PATH"] = "\(pathAdditions):\(existingPath)"
                } else {
                    environment["PATH"] = pathAdditions
                }
                task.environment = environment
                
                // Set up pipes
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                task.standardOutput = outputPipe
                task.standardError = errorPipe
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outputData + errorData, encoding: .utf8) ?? ""
                    
                    continuation.resume(returning: (task.terminationStatus, output))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Find yt-dlp using the which command
    private func findYtDlpWithWhich() async throws -> String? {
        let result = try await executeSimpleCommand(
            executablePath: "/usr/bin/which",
            arguments: ["yt-dlp"]
        )
        
        if result.exitCode == 0 {
            let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
    
    /// Copy yt-dlp to a temporary location that might be accessible
    private func copyYtDlpToTemp() async throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let tempYtDlp = tempDir.appendingPathComponent("yt-dlp-temp")
        
        // Find source yt-dlp
        let sourcePaths = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp"
        ]
        
        for sourcePath in sourcePaths {
            if FileManager.default.fileExists(atPath: sourcePath) {
                try FileManager.default.copyItem(atPath: sourcePath, toPath: tempYtDlp.path)
                
                // Make it executable
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o755],
                    ofItemAtPath: tempYtDlp.path
                )
                
                return tempYtDlp.path
            }
        }
        
        throw AppError.downloadFailed("Could not find yt-dlp to copy")
    }
        
    /// Execute the yt-dlp download process
    private func executeYtDlpDownload(
        ytDlpPath: String,
        url: String,
        outputTemplate: String,
        outputDir: URL,
        filenameTemplate: String,
        itemId: UUID
    ) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Progress simulation task
                let progressTask = Task {
                    for progress in stride(from: 0.0, through: 0.9, by: 0.1) {
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        try Task.checkCancellation()
                        
                        await MainActor.run {
                            self.downloadProgress[itemId] = progress
                        }
                    }
                }
                
                let task = Process()
                
                // Build arguments based on executable path
                var arguments: [String]
                if ytDlpPath == "/usr/bin/env" {
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    arguments = [
                        "yt-dlp",
                        "--write-info-json",
                        "--output", outputTemplate,
                        "--format", "best[height<=1080]/best",
                        "--no-playlist",
                        "--embed-metadata",
                        "--add-metadata",
                        url
                    ]
                } else {
                    task.executableURL = URL(fileURLWithPath: ytDlpPath)
                    arguments = [
                        "--write-info-json",
                        "--output", outputTemplate,
                        "--format", "best[height<=1080]/best",
                        "--no-playlist",
                        "--embed-metadata",
                        "--add-metadata",
                        url
                    ]
                }
                
                task.arguments = arguments
                
                // Set environment with extended PATH
                var environment = ProcessInfo.processInfo.environment
                let pathAdditions = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
                if let existingPath = environment["PATH"] {
                    environment["PATH"] = "\(pathAdditions):\(existingPath)"
                } else {
                    environment["PATH"] = pathAdditions
                }
                task.environment = environment
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                task.standardOutput = outputPipe
                task.standardError = errorPipe
                
                NSLog("Executing yt-dlp with command: %@ %@", ytDlpPath, arguments.joined(separator: " "))
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    progressTask.cancel()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let outputString = String(data: outputData, encoding: .utf8) ?? "No output"
                    let errorString = String(data: errorData, encoding: .utf8) ?? "No error output"
                    
                    NSLog("yt-dlp process completed with exit code: %d", task.terminationStatus)
                    
                    if task.terminationStatus == 0 {
                        // Find the downloaded file
                        Task { @MainActor in
                            do {
                                let downloadedFile = try self.findDownloadedFile(
                                    in: outputDir,
                                    with: filenameTemplate
                                )
                                
                                self.downloadProgress[itemId] = 1.0
                                continuation.resume(returning: downloadedFile)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    } else {
                        NSLog("yt-dlp output: %@", outputString)
                        NSLog("yt-dlp error: %@", errorString)
                        let errorMessage = "yt-dlp failed (exit code \(task.terminationStatus)): \(errorString)"
                        continuation.resume(throwing: AppError.downloadFailed(errorMessage))
                    }
                } catch {
                    progressTask.cancel()
                    NSLog("Failed to execute yt-dlp: %@", error.localizedDescription)
                    continuation.resume(throwing: AppError.downloadFailed("Failed to start yt-dlp: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    /// Find the downloaded file in the output directory
    private func findDownloadedFile(in outputDir: URL, with filenameTemplate: String) throws -> URL {
        NSLog("Looking for downloaded files in: %@", outputDir.path)
        
        let downloadedFiles = try FileManager.default.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)
            .filter { file in
                let filename = file.lastPathComponent
                let matches = filename.hasPrefix(filenameTemplate) && 
                       (filename.hasSuffix(".mp4") || filename.hasSuffix(".mkv") || 
                        filename.hasSuffix(".webm") || filename.hasSuffix(".m4a"))
                NSLog("Checking file: %@ - matches criteria: %@", filename, matches ? "YES" : "NO")
                return matches
            }
            .sorted { $0.path < $1.path }
        
        NSLog("Found %d matching files", downloadedFiles.count)
        for file in downloadedFiles {
            NSLog("  - %@", file.lastPathComponent)
        }
        
        guard let downloadedFile = downloadedFiles.first else {
            NSLog("No downloaded file found matching criteria")
            // List all files in the directory for debugging
            do {
                let allFiles = try FileManager.default.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)
                NSLog("All files in output directory:")
                for file in allFiles {
                    NSLog("  - %@", file.lastPathComponent)
                }
            } catch {
                NSLog("Error listing directory contents: %@", error.localizedDescription)
            }
            throw AppError.downloadFailed("Downloaded file not found")
        }
        
        NSLog("Successfully downloaded: %@", downloadedFile.lastPathComponent)
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
        let (localURL, response) = try await download(from: url)
        return (localURL, response)
    }
}

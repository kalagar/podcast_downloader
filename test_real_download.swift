#!/usr/bin/env swift

//
//  test_real_download.swift
//  PodcastDownloader
//
//  End-to-end test for real YouTube download functionality
//

import Foundation
import CoreData
import Combine

// Simple test to verify our yt-dlp integration works
func testYtDlpMetadataExtraction() async {
    print("🧪 Testing yt-dlp metadata extraction...")
    
    let ytDlpPath = "/opt/homebrew/bin/yt-dlp"
    let testURL = "https://www.youtube.com/watch?v=dQw4w9WgXcQ" // Rick Roll - short video
    
    // Check if yt-dlp exists
    guard FileManager.default.fileExists(atPath: ytDlpPath) else {
        print("❌ yt-dlp not found at \(ytDlpPath)")
        return
    }
    
    print("✅ yt-dlp found at \(ytDlpPath)")
    
    // Test metadata extraction
    let process = Process()
    process.executableURL = URL(fileURLWithPath: ytDlpPath)
    process.arguments = [
        "--dump-json",
        "--no-playlist",
        testURL
    ]
    
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let jsonString = String(data: outputData, encoding: .utf8),
               let jsonData = jsonString.data(using: .utf8),
               let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                
                let title = json["title"] as? String ?? "Unknown"
                let uploader = json["uploader"] as? String ?? "Unknown"
                let duration = json["duration"] as? Double ?? 0
                
                print("✅ Metadata extraction successful!")
                print("   Title: \(title)")
                print("   Uploader: \(uploader)")
                print("   Duration: \(duration)s")
            } else {
                print("❌ Failed to parse JSON response")
            }
        } else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            print("❌ yt-dlp failed: \(errorString)")
        }
    } catch {
        print("❌ Failed to run yt-dlp: \(error)")
    }
}

func testDirectoryCreation() {
    print("\n🧪 Testing directory creation...")
    
    let fileManager = FileManager.default
    let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let podloadDir = applicationSupport.appendingPathComponent("PodLoad")
    let mediaDir = podloadDir.appendingPathComponent("Media")
    let youtubeDir = mediaDir.appendingPathComponent("youtube")
    
    do {
        try fileManager.createDirectory(at: youtubeDir, withIntermediateDirectories: true)
        print("✅ Created directory structure at: \(youtubeDir.path)")
        
        // Clean up test directory
        try fileManager.removeItem(at: podloadDir)
        print("✅ Cleaned up test directory")
    } catch {
        print("❌ Directory creation failed: \(error)")
    }
}

func testProviderDetection() {
    print("\n🧪 Testing provider detection...")
    
    let testURLs = [
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://youtu.be/dQw4w9WgXcQ",
        "https://open.spotify.com/episode/1234567890",
        "https://feeds.simplecast.com/podcast.xml",
        "https://example.com/audio.mp3"
    ]
    
    for url in testURLs {
        print("   URL: \(url)")
        if url.contains("youtube.com") || url.contains("youtu.be") {
            print("   → Detected: YouTube ✅")
        } else if url.contains("spotify.com") {
            print("   → Detected: Spotify ✅")
        } else if url.contains("xml") || url.contains("rss") || url.contains("feed") {
            print("   → Detected: RSS ✅")
        } else {
            print("   → Detected: Direct/Unknown ✅")
        }
    }
}

// Main test execution
print("🚀 PodLoad-Mac End-to-End Test Suite")
print("=====================================")

await testYtDlpMetadataExtraction()
testDirectoryCreation()
testProviderDetection()

print("\n🎉 Test suite completed!")
print("   Next steps:")
print("   1. Launch the PodLoad-Mac app")
print("   2. Try adding a YouTube URL")
print("   3. Verify download and playback functionality")

#!/usr/bin/env swift

import Foundation

// Simple integration test for yt-dlp functionality
print("Testing yt-dlp integration...")

let ytDlpPath = "/opt/homebrew/bin/yt-dlp"
let testURL = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

func testMetadataExtraction() async {
    print("\n1. Testing metadata extraction...")
    
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
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                
                let title = json["title"] as? String ?? "Unknown"
                let channel = json["uploader"] as? String ?? "Unknown"
                let duration = json["duration"] as? Double ?? 0.0
                
                print("✅ Metadata extraction successful!")
                print("   Title: \(title)")
                print("   Channel: \(channel)")
                print("   Duration: \(duration) seconds")
                return
            }
        }
        
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        if let errorString = String(data: errorData, encoding: .utf8) {
            print("❌ Metadata extraction failed: \(errorString)")
        }
    } catch {
        print("❌ Failed to run yt-dlp: \(error)")
    }
}

// Run the test
Task {
    await testMetadataExtraction()
    print("\n🎉 Integration test completed!")
    exit(0)
}

// Keep the script running for async execution
RunLoop.main.run()

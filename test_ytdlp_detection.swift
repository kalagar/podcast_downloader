#!/usr/bin/swift

import Foundation

// Simple test to verify yt-dlp detection outside of sandbox
func testYtDlpDetection() {
    let possiblePaths = [
        "/opt/homebrew/bin/yt-dlp",
        "/usr/local/bin/yt-dlp",
        "/usr/bin/yt-dlp"
    ]
    
    print("Testing yt-dlp detection:")
    for path in possiblePaths {
        let exists = FileManager.default.fileExists(atPath: path)
        let executable = exists ? FileManager.default.isExecutableFile(atPath: path) : false
        print("  \(path): exists=\(exists), executable=\(executable)")
        
        if exists && executable {
            // Try to run it
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["--version"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    print("    Version: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            } catch {
                print("    Error running: \(error)")
            }
        }
    }
    
    // Test env approach
    print("\nTesting env approach:")
    let envProcess = Process()
    envProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    envProcess.arguments = ["yt-dlp", "--version"]
    
    var environment = ProcessInfo.processInfo.environment
    let pathAdditions = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
    if let existingPath = environment["PATH"] {
        environment["PATH"] = "\(pathAdditions):\(existingPath)"
    } else {
        environment["PATH"] = pathAdditions
    }
    envProcess.environment = environment
    
    let envPipe = Pipe()
    envProcess.standardOutput = envPipe
    
    do {
        try envProcess.run()
        envProcess.waitUntilExit()
        
        let data = envPipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            print("  env yt-dlp --version: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    } catch {
        print("  env approach error: \(error)")
    }
}

testYtDlpDetection()

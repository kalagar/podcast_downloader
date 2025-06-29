#!/usr/bin/env swift

import Foundation

/// Test the same logic we implemented in MediaDownloader
func testYtDlpPath(_ path: String) async -> Bool {
    do {
        let result = try await executeSimpleCommand(
            executablePath: path,
            arguments: ["--version"]
        )
        print("Path \(path) test result: exit=\(result.exitCode), output: \(result.output.prefix(100))")
        return result.exitCode == 0
    } catch {
        print("Path \(path) test failed: \(error)")
        return false
    }
}

func executeSimpleCommand(
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

func testEnvYtDlp() async -> Bool {
    do {
        let result = try await executeSimpleCommand(
            executablePath: "/usr/bin/env",
            arguments: ["yt-dlp", "--version"]
        )
        print("/usr/bin/env yt-dlp test result: exit=\(result.exitCode)")
        return result.exitCode == 0
    } catch {
        print("/usr/bin/env yt-dlp test failed: \(error)")
        return false
    }
}

// Main test function
func runTests() async {
    print("=== Testing yt-dlp detection (same logic as in MediaDownloader) ===")
    
    // Strategy 1: Check common installation paths
    let commonPaths = [
        "/opt/homebrew/bin/yt-dlp",
        "/usr/local/bin/yt-dlp",
        "/usr/bin/yt-dlp"
    ]
    
    for path in commonPaths {
        print("Testing path: \(path)")
        if await testYtDlpPath(path) {
            print("✅ Found working yt-dlp at: \(path)")
            break
        }
    }
    
    // Strategy 2: Test /usr/bin/env approach
    print("Testing /usr/bin/env approach...")
    if await testEnvYtDlp() {
        print("✅ /usr/bin/env approach works!")
    } else {
        print("❌ /usr/bin/env approach failed")
    }
    
    print("=== Test completed ===")
}

// Run the async function
Task {
    await runTests()
    exit(0)
}

// Keep the script running
RunLoop.main.run()

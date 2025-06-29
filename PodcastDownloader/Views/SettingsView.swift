//
//  SettingsView.swift
//  PodcastDownloader
//
//  Created by Mansour Kalagar on 28.06.25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("downloadQuality") private var downloadQuality = "best"
    @AppStorage("autoDownload") private var autoDownload = false
    @AppStorage("maxConcurrentDownloads") private var maxConcurrentDownloads = 3
    @AppStorage("downloadLocation") private var downloadLocation = ""
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("deleteAfterWatching") private var deleteAfterWatching = false
    
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                generalSection
                downloadSection
                storageSection
                notificationSection
                networkSection
                aboutSection
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }
    
    @ViewBuilder
    private var generalSection: some View {
        Section("General") {
            Toggle("Enable Notifications", isOn: $enableNotifications)
            Toggle("Auto-download new items", isOn: $autoDownload)
            Toggle("Delete after watching", isOn: $deleteAfterWatching)
        }
    }
    
    @ViewBuilder
    private var downloadSection: some View {
        Section("Downloads") {
            Picker("Quality", selection: $downloadQuality) {
                Text("Best").tag("best")
                Text("720p").tag("720p")
                Text("480p").tag("480p")
                Text("Audio Only").tag("audio")
            }
            .pickerStyle(SegmentedPickerStyle())
            
            VStack(alignment: .leading) {
                Text("Max Concurrent Downloads: \\(maxConcurrentDownloads)")
                Slider(value: .init(
                    get: { Double(maxConcurrentDownloads) },
                    set: { maxConcurrentDownloads = Int($0) }
                ), in: 1...10, step: 1)
            }
            
            HStack {
                Text("Download Location:")
                Spacer()
                Text(downloadLocation.isEmpty ? "Default" : downloadLocation)
                    .foregroundColor(.secondary)
                Button("Choose...") {
                    chooseDownloadLocation()
                }
            }
        }
    }
    
    @ViewBuilder
    private var storageSection: some View {
        Section("Storage") {
            HStack {
                Text("Cache Size")
                Spacer()
                Text("~125 MB")
                    .foregroundColor(.secondary)
                Button("Clear") {
                    clearCache()
                }
            }
            
            Button("Export Library") {
                exportLibrary()
            }
            
            Button("Import Library") {
                importLibrary()
            }
        }
    }
    
    @ViewBuilder
    private var notificationSection: some View {
        Section("Notifications") {
            Toggle("Download complete", isOn: .constant(enableNotifications))
                .disabled(!enableNotifications)
            Toggle("Download failed", isOn: .constant(enableNotifications))
                .disabled(!enableNotifications)
            Toggle("New items available", isOn: .constant(enableNotifications))
                .disabled(!enableNotifications)
        }
    }
    
    @ViewBuilder
    private var networkSection: some View {
        Section("Network") {
            HStack {
                Text("Connection Status")
                Spacer()
                HStack {
                    Circle()
                        .fill(networkMonitor.isConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(networkMonitor.isConnected ? "Connected" : "Disconnected")
                        .foregroundColor(.secondary)
                }
            }
            
            if networkMonitor.isConnected {
                HStack {
                    Text("Connection Type")
                    Spacer()
                    Text(networkMonitor.connectionDescription)
                        .foregroundColor(.secondary)
                }
            }
            
            Toggle("Download only on Wi-Fi", isOn: .constant(false))
        }
    }
    
    @ViewBuilder
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text("2025.06.28")
                    .foregroundColor(.secondary)
            }
            
            Link("GitHub Repository", destination: URL(string: "https://github.com/yourusername/PodLoad-Mac")!)
            Link("Support", destination: URL(string: "mailto:support@example.com")!)
        }
    }
    
    private func chooseDownloadLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            downloadLocation = panel.url?.path ?? ""
        }
    }
    
    private func clearCache() {
        // Implementation for clearing cache
        print("Clearing cache...")
    }
    
    private func exportLibrary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "PodLoad-Library-Export.json"
        
        if panel.runModal() == .OK {
            // Implementation for exporting library
            print("Exporting library to: \(panel.url?.path ?? "")")
        }
    }
    
    private func importLibrary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            // Implementation for importing library
            print("Importing library from: \(panel.url?.path ?? "")")
        }
    }
}

#Preview {
    SettingsView()
}

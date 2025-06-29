//
//  MediaDetailView.swift
//  PodcastDownloader
//
//  Created by AI Assistant on 6/28/25.
//

import SwiftUI
import AVKit

struct MediaDetailView: View {
    let mediaItem: MediaItem
    @StateObject private var mediaPlayer = MediaPlayer()
    @State private var isExpanded = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with artwork and basic info
                headerSection
                
                // Playback controls
                if (mediaItem.hasVideo && mediaItem.localVideoPath != nil) || 
                   (!mediaItem.hasVideo && mediaItem.localAudioPath != nil) {
                    playbackSection
                }
                
                // Metadata section
                metadataSection
                
                // Actions section
                actionsSection
            }
            .padding()
        }
        .navigationTitle(mediaItem.title ?? "Unknown Title")
        .navigationSubtitle(mediaItem.showOrChannel ?? "Unknown Creator")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Delete") {
                    showingDeleteConfirmation = true
                }
                .foregroundColor(.red)
            }
        }
        .confirmationDialog("Delete Media", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteMediaItem()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(mediaItem.title ?? "this item")'? This action cannot be undone.")
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Artwork
            AsyncImage(url: URL(string: mediaItem.artworkURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: mediaItem.hasVideo ? "tv" : "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 8) {
                Text(mediaItem.title ?? "Unknown Title")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(mediaItem.showOrChannel ?? "Unknown Creator")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Label(formatDuration(mediaItem.duration), systemImage: "clock")
                    
                    if mediaItem.hasVideo {
                        Label("Video", systemImage: "tv")
                    } else {
                        Label("Audio", systemImage: "music.note")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                if mediaItem.isWatched {
                    Label("Watched", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                // Source provider badge
                SourceProviderBadge(provider: SourceProvider(rawValue: mediaItem.sourceProvider ?? "unknown") ?? .unknown)
            }
            
            Spacer()
        }
    }
    
    private var playbackSection: some View {
        VStack(spacing: 16) {
            // Audio visualizer (if audio mode)
            if mediaPlayer.playbackMode == .audio {
                AudioVisualizerView(isPlaying: mediaPlayer.isPlaying)
                    .frame(height: 60)
            }
            
            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: mediaPlayer.currentTime, total: mediaPlayer.duration)
                    .progressViewStyle(LinearProgressViewStyle())
                
                HStack {
                    Text(formatDuration(mediaPlayer.currentTime))
                    Spacer()
                    Text(formatDuration(mediaPlayer.duration))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Playback controls
            HStack(spacing: 24) {
                Button(action: { Task { await mediaPlayer.skipBackward() } }) {
                    Image(systemName: "gobackward.30")
                        .font(.title2)
                }
                
                Button(action: { 
                    Task { 
                        if mediaPlayer.isPlaying {
                            await mediaPlayer.pause()
                        } else {
                            if mediaPlayer.currentItem == nil {
                                await mediaPlayer.loadMedia(mediaItem)
                            }
                            await mediaPlayer.play()
                        }
                    }
                }) {
                    Image(systemName: mediaPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                }
                .disabled(mediaPlayer.isLoading)
                
                Button(action: { Task { await mediaPlayer.skipForward() } }) {
                    Image(systemName: "goforward.30")
                        .font(.title2)
                }
                
                VolumeSlider(volume: $mediaPlayer.volume)
                    .frame(width: 80)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(minimum: 200), alignment: .leading)
            ], spacing: 8) {
                DetailRow(title: "Published", value: formatDate(mediaItem.publishDate))
                DetailRow(title: "Downloaded", value: formatDate(mediaItem.downloadDate))
                DetailRow(title: "Duration", value: formatDuration(mediaItem.duration))
                DetailRow(title: "File Size", value: formatFileSize(mediaItem.fileSize))
                DetailRow(title: "Source", value: mediaItem.sourceProvider?.capitalized ?? "Unknown")
                DetailRow(title: "Tags", value: mediaItem.tags ?? "None")
            }
            
            if let description = mediaItem.itemDescription, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(description)
                        .font(.body)
                        .lineLimit(isExpanded ? nil : 3)
                    
                    Button(isExpanded ? "Show Less" : "Show More") {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Text("Actions")
                .font(.headline)
            
            HStack(spacing: 16) {
                if let originalURL = mediaItem.originalURL {
                    Button("Open Original") {
                        if let url = URL(string: originalURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                let filePath = mediaItem.hasVideo ? mediaItem.localVideoPath : mediaItem.localAudioPath
                if let path = filePath, !path.isEmpty {
                    Button("Show in Finder") {
                        let url = URL(fileURLWithPath: path)
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    .buttonStyle(.bordered)
                }
                
                Button(mediaItem.isWatched ? "Mark as Unwatched" : "Mark as Watched") {
                    toggleWatchedStatus()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func toggleWatchedStatus() {
        mediaItem.isWatched.toggle()
        if mediaItem.isWatched {
            mediaItem.lastWatchedDate = Date()
        }
        
        try? mediaItem.managedObjectContext?.save()
    }
    
    private func deleteMediaItem() {
        // Delete the actual files if they exist
        if let audioPath = mediaItem.localAudioPath, !audioPath.isEmpty {
            try? FileManager.default.removeItem(atPath: audioPath)
        }
        if let videoPath = mediaItem.localVideoPath, !videoPath.isEmpty {
            try? FileManager.default.removeItem(atPath: videoPath)
        }
        if let artworkPath = mediaItem.localArtworkPath, !artworkPath.isEmpty {
            try? FileManager.default.removeItem(atPath: artworkPath)
        }
        
        // Delete from Core Data
        mediaItem.managedObjectContext?.delete(mediaItem)
        try? mediaItem.managedObjectContext?.save()
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundColor(.secondary)
        
        Text(value)
            .font(.caption)
    }
}

struct VolumeSlider: View {
    @Binding var volume: Float
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Slider(value: $volume, in: 0...1)
                .frame(width: 60)
        }
    }
}

struct SourceProviderBadge: View {
    let provider: SourceProvider
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: provider.iconName)
            Text(provider.displayName)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(provider.color.opacity(0.2))
        .foregroundColor(provider.color)
        .clipShape(Capsule())
    }
}

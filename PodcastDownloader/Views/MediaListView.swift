//
//  MediaListView.swift
//  PodcastDownloader
//
//  Created by Mansour Kalagar on 28.06.25.
//

import SwiftUI
import CoreData

struct MediaListView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest var mediaItems: FetchedResults<MediaItem>
    
    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
        self._mediaItems = FetchRequest(fetchRequest: viewModel.fetchRequest)
    }
    
    var body: some View {
        if mediaItems.isEmpty {
            EmptyStateView()
        } else {
            MediaTable()
        }
    }
    
    @ViewBuilder
    private func EmptyStateView() -> some View {
        VStack {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No media items yet")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Press ⌘N to add your first item")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder 
    private func MediaTable() -> some View {
        List(Array(mediaItems), id: \.id, selection: $viewModel.selectedMediaItem) { item in
            MediaRowView(item: item, viewModel: viewModel)
        }
        .listStyle(PlainListStyle())
        .contextMenu(forSelectionType: MediaItem.self) { items in
            ContextMenuView(items: items, viewModel: viewModel)
        }
    }
    
    
    private func formatDuration(_ duration: Double) -> String {
        if duration <= 0 { return "--" }
        
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct MediaRowView: View {
    let item: MediaItem
    let viewModel: LibraryViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? "Unknown Title")
                    .font(.headline)
                    .lineLimit(1)
                
                Text(item.showOrChannel ?? "Unknown")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let status = item.downloadStatus, status != "completed" {
                    HStack {
                        Text(status.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if status == "downloading" {
                            ProgressView(value: item.downloadProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(width: 60)
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Image(systemName: item.hasVideo ? "video" : "waveform")
                        .foregroundColor(item.hasVideo ? .blue : .green)
                    Text(formatDuration(item.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(item.downloadDate ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: { viewModel.toggleWatched(for: item) }) {
                    HStack {
                        Image(systemName: item.isWatched ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isWatched ? .green : .secondary)
                        Text(item.isWatched ? "Watched" : "Unwatched")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        if duration <= 0 { return "--" }
        
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct TitleColumnView: View {
    let item: MediaItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title ?? "Unknown Title")
                .font(.headline)
                .lineLimit(1)
            
            if let status = item.downloadStatus, status != "completed" {
                HStack {
                    Text(status.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if status == "downloading" {
                        ProgressView(value: item.downloadProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 60)
                    }
                }
            }
        }
    }
}

struct TypeColumnView: View {
    let item: MediaItem
    
    var body: some View {
        HStack {
            Image(systemName: item.hasVideo ? "video" : "waveform")
                .foregroundColor(item.hasVideo ? .blue : .green)
            Text(item.hasVideo ? "Video" : "Audio")
                .font(.caption)
        }
    }
}

struct StatusColumnView: View {
    let item: MediaItem
    let viewModel: LibraryViewModel
    
    var body: some View {
        HStack {
            if item.isWatched {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
            }
            
            Button(action: { viewModel.toggleWatched(for: item) }) {
                Text(item.isWatched ? "Watched" : "Unwatched")
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
    }
}

struct ContextMenuView: View {
    let items: Set<MediaItem>
    let viewModel: LibraryViewModel
    
    var body: some View {
        if let item = items.first {
            Button("Toggle Watched") {
                viewModel.toggleWatched(for: item)
            }
            
            Button("Delete") {
                viewModel.deleteMediaItem(item)
            }
            
            Divider()
            
            if let url = item.originalURL {
                Button("Open Original URL") {
                    if let nsUrl = URL(string: url) {
                        NSWorkspace.shared.open(nsUrl)
                    }
                }
            }
        }
    }
}

#Preview {
    MediaListView(viewModel: LibraryViewModel(persistenceController: .preview))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .frame(width: 800, height: 400)
}

//
//  ContentView.swift
//  PodcastDownloader
//
//  Created by Mansour Kalagar on 28.06.25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingSettings = false
    @State private var currentError: AppError?
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(viewModel: viewModel)
        } content: {
            // Main content area
            VStack(spacing: 0) {
                // Toolbar
                ToolbarView(
                    viewModel: viewModel,
                    onSettings: { showingSettings = true }
                )
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Media list
                MediaListView(viewModel: viewModel)
            }
        } detail: {
            // Detail view
            if let selectedItem = viewModel.selectedMediaItem {
                MediaDetailView(mediaItem: selectedItem)
            } else {
                VStack {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Select a media item to view details")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Press ⌘N to add new media")
                        .font(.subheadline)
                        .foregroundColor(Color(.tertiaryLabelColor))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 1024, minHeight: 640)
        .sheet(isPresented: $viewModel.isShowingAddSheet) {
            AddMediaSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert(item: $currentError) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.errorDescription ?? "An unknown error occurred"),
                primaryButton: .default(Text("OK")),
                secondaryButton: .cancel(Text("Dismiss"))
            )
        }
        .onReceive(viewModel.$currentError) { error in
            currentError = error
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

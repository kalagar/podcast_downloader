//
//  ToolbarView.swift
//  PodcastDownloader
//
//  Created by Mansour Kalagar on 28.06.25.
//

import SwiftUI

struct ToolbarView: View {
    @ObservedObject var viewModel: LibraryViewModel
    let onSettings: () -> Void
    
    init(viewModel: LibraryViewModel, onSettings: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onSettings = onSettings
    }
    
    var body: some View {
        HStack {
            // Add button
            Button(action: viewModel.addNewItem) {
                Label("Add", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            
            // Delete button
            Button(action: {
                if let selected = viewModel.selectedMediaItem {
                    viewModel.deleteMediaItem(selected)
                }
            }) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(viewModel.selectedMediaItem == nil)
            
            Divider()
            
            // Sort menu
            Menu {
                Picker("Sort by", selection: $viewModel.sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                
                Divider()
                
                Toggle("Ascending", isOn: $viewModel.sortAscending)
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            
            // Filter menu (placeholder for future filters)
            Menu {
                Text("Audio Only")
                Text("Video Capable")
                Divider()
                Text("Watched")
                Text("Unwatched")
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
            
            Spacer()
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .frame(width: 250)
            
            // Settings button
            Button(action: onSettings) {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    ToolbarView(viewModel: LibraryViewModel(persistenceController: .preview))
        .frame(height: 44)
}

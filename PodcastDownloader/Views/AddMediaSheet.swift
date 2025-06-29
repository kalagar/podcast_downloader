//
//  AddMediaSheet.swift
//  PodcastDownloader
//
//  Created by Mansour Kalagar on 28.06.25.
//

import SwiftUI

struct AddMediaSheet: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                
                Text("Add New Media")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Paste a URL from YouTube, Spotify, or RSS feed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // URL Input
            VStack(alignment: .leading, spacing: 8) {
                Text("URL")
                    .font(.headline)
                
                TextField("https://www.youtube.com/watch?v=...", text: $viewModel.newItemURL)
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 32)
                
                if let error = viewModel.downloadError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Provider Detection
            if !viewModel.newItemURL.isEmpty {
                let provider = SourceProvider.detectProvider(from: viewModel.newItemURL)
                
                HStack {
                    Image(systemName: provider.iconName)
                        .foregroundColor(provider == .unknown ? .red : .accentColor)
                    
                    Text("Detected: \(provider.displayName)")
                        .font(.subheadline)
                        .foregroundColor(provider == .unknown ? .red : .secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Download") {
                    viewModel.downloadFromURL()
                }
                .keyboardShortcut(.return)
                .disabled(viewModel.newItemURL.isEmpty || viewModel.isDownloading)
                .buttonStyle(.borderedProminent)
            }
            
            // Progress indicator
            if viewModel.isDownloading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Downloading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(width: 500, height: 350)
        .onAppear {
            // Try to get URL from clipboard
            if let clipboardString = NSPasteboard.general.string(forType: .string),
               clipboardString.hasPrefix("http") {
                viewModel.newItemURL = clipboardString
            }
        }
    }
}

#Preview {
    AddMediaSheet(viewModel: LibraryViewModel(persistenceController: .preview))
}

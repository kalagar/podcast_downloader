//
//  SidebarView.swift
//  PodcastDownloader
//
//  Created by Mansour Kalagar on 28.06.25.
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: LibraryViewModel
    
    var body: some View {
        List(selection: $viewModel.selectedSource) {
            Section("Sources") {
                // All items
                Label("All", systemImage: "tray.2")
                    .tag(nil as SourceProvider?)
                
                // Individual sources
                ForEach(SourceProvider.allCases.filter { $0 != .unknown }, id: \.self) { source in
                    Label(source.displayName, systemImage: source.iconName)
                        .tag(source as SourceProvider?)
                }
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
}

#Preview {
    SidebarView(viewModel: LibraryViewModel(persistenceController: .preview))
        .frame(width: 200, height: 400)
}

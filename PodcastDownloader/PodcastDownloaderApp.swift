//
//  PodcastDownloaderApp.swift
//  PodcastDownloader
//
//  Created by Mansour Kalagar on 28.06.25.
//

import SwiftUI

@main
struct PodcastDownloaderApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.context)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Add Media...") {
                    // This will be handled by the view model's keyboard shortcut
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

//
//  PersistenceController.swift
//  PodcastDownloader
//
//  Created by Mansour Kalagar on 28.06.25.
//

import CoreData
import Foundation
import OSLog

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    private let logger = Logger(subsystem: "com.podload.mac", category: "persistence")
    
    let container: NSPersistentContainer
    
    var context: NSManagedObjectContext {
        container.viewContext
    }
    
    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                logger.error("Failed to save context: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Preview Support
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // Create sample data for previews
        let sampleItem = MediaItem(context: context)
        sampleItem.id = UUID()
        sampleItem.title = "Sample YouTube Video"
        sampleItem.showOrChannel = "Sample Channel"
        sampleItem.sourceProvider = "YouTube"
        sampleItem.originalURL = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        sampleItem.downloadDate = Date()
        sampleItem.hasVideo = true
        sampleItem.downloadStatus = "completed"
        
        try? context.save()
        return controller
    }()
    
    // MARK: - Initializers
    
    public init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "PodLoadModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Set up store location in Application Support
            let storeURL = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first!
                .appendingPathComponent("PodLoad")
                .appendingPathComponent("PodLoadModel.sqlite")
            
            // Create directory if needed
            try? FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            let description = NSPersistentStoreDescription(url: storeURL)
            description.shouldInferMappingModelAutomatically = true
            description.shouldMigrateStoreAutomatically = true
            container.persistentStoreDescriptions = [description]
        }
        
        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                self?.logger.error("Core Data failed to load: \(error.localizedDescription)")
                fatalError("Core Data error: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

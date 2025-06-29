//
//  LibraryViewModel.swift
//  PodcastDownloader
//
//  Created by Mansour Kalagar on 28.06.25.
//

import Foundation
import CoreData
import Combine
import OSLog

enum SortOption: String, CaseIterable {
    case title = "Title"
    case showChannel = "Show/Channel"
    case publishDate = "Publish Date"
    case downloadDate = "Download Date"
    case duration = "Duration"
    case watched = "Watched/Unwatched"
    
    var keyPath: String {
        switch self {
        case .title: return "title"
        case .showChannel: return "showOrChannel"
        case .publishDate: return "publishDate"
        case .downloadDate: return "downloadDate"
        case .duration: return "duration"
        case .watched: return "isWatched"
        }
    }
}

@MainActor
class LibraryViewModel: ObservableObject {
    private let persistenceController: PersistenceController
    private let downloadService: DownloadService
    private let logger = Logger(subsystem: "com.podload.mac", category: "library")
    
    // UI State
    @Published var selectedSource: SourceProvider? = nil
    @Published var sortOption: SortOption = .downloadDate
    @Published var sortAscending: Bool = false
    @Published var searchText: String = ""
    @Published var selectedMediaItem: MediaItem? = nil
    @Published var isShowingAddSheet: Bool = false
    @Published var newItemURL: String = ""
    
    // Download state
    @Published var isDownloading: Bool = false
    @Published var downloadError: String? = nil
    @Published var currentError: AppError?
    
    private var cancellables = Set<AnyCancellable>()
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.downloadService = DownloadService(persistenceController: persistenceController)
        
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        NetworkMonitor.shared.$isConnected
            .sink { [weak self] isConnected in
                if !isConnected {
                    self?.currentError = .networkUnavailable
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Access
    
    var fetchRequest: NSFetchRequest<MediaItem> {
        let request = MediaItem.fetchRequest()
        
        // Apply source filter
        var predicates: [NSPredicate] = []
        
        if let selectedSource = selectedSource {
            predicates.append(NSPredicate(format: "sourceProvider == %@", selectedSource.rawValue))
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            let searchPredicate = NSPredicate(format: "title CONTAINS[cd] %@ OR itemDescription CONTAINS[cd] %@ OR showOrChannel CONTAINS[cd] %@", searchText, searchText, searchText)
            predicates.append(searchPredicate)
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        // Apply sorting
        let sortDescriptor = NSSortDescriptor(
            key: sortOption.keyPath,
            ascending: sortAscending
        )
        request.sortDescriptors = [sortDescriptor]
        
        return request
    }
    
    // MARK: - Actions
    
    func addNewItem() {
        isShowingAddSheet = true
        newItemURL = ""
        downloadError = nil
    }
    
    func downloadFromURL() {
        guard !newItemURL.isEmpty else { return }
        
        isDownloading = true
        downloadError = nil
        
        Task {
            do {
                let mediaItem = try await downloadService.downloadMedia(from: newItemURL)
                await MainActor.run {
                    self.isDownloading = false
                    self.isShowingAddSheet = false
                    self.selectedMediaItem = mediaItem
                    self.logger.info("Successfully downloaded: \(mediaItem.title ?? "Unknown")")
                }
            } catch {
                await MainActor.run {
                    self.isDownloading = false
                    self.downloadError = error.localizedDescription
                    self.logger.error("Download failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func deleteMediaItem(_ mediaItem: MediaItem) {
        // Delete local files
        deleteLocalFiles(for: mediaItem)
        
        // Delete from Core Data
        persistenceController.context.delete(mediaItem)
        persistenceController.save()
        
        if selectedMediaItem == mediaItem {
            selectedMediaItem = nil
        }
    }
    
    func toggleWatched(for mediaItem: MediaItem) {
        mediaItem.isWatched.toggle()
        persistenceController.save()
    }
    
    func updatePlayPosition(for mediaItem: MediaItem, position: TimeInterval) {
        mediaItem.lastPlayPosition = position
        persistenceController.save()
    }
    
    // MARK: - Private Methods
    
    private func deleteLocalFiles(for mediaItem: MediaItem) {
        let fileManager = FileManager.default
        
        if let audioPath = mediaItem.localAudioPath {
            try? fileManager.removeItem(atPath: audioPath)
        }
        
        if let videoPath = mediaItem.localVideoPath {
            try? fileManager.removeItem(atPath: videoPath)
        }
        
        if let artworkPath = mediaItem.localArtworkPath {
            try? fileManager.removeItem(atPath: artworkPath)
        }
        
        // Try to remove the media directory if empty
        if let audioPath = mediaItem.localAudioPath {
            let mediaDir = URL(fileURLWithPath: audioPath).deletingLastPathComponent()
            try? fileManager.removeItem(at: mediaDir)
        }
    }
}

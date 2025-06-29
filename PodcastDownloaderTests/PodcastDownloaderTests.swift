//
//  PodcastDownloaderTests.swift
//  PodcastDownloaderTests
//
//  Created by Mansour Kalagar on 28.06.25.
//

import XCTest
import CoreData
@testable import PodcastDownloader

final class PodcastDownloaderTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    
    override func setUpWithError() throws {
        // Create in-memory Core Data stack for testing
        persistenceController = PersistenceController(inMemory: true)
    }
    
    override func tearDownWithError() throws {
        persistenceController = nil
    }
    
    // MARK: - Source Provider Tests
    
    func testYouTubeURLDetection() throws {
        let youtubeURL1 = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        let youtubeURL2 = "https://youtu.be/dQw4w9WgXcQ"
        
        XCTAssertEqual(SourceProvider.detectProvider(from: youtubeURL1), .youtube)
        XCTAssertEqual(SourceProvider.detectProvider(from: youtubeURL2), .youtube)
    }
    
    func testSpotifyURLDetection() throws {
        let spotifyURL = "https://podcasters.spotify.com/pod/show/lexfridman/episodes/1-Meta"
        
        XCTAssertEqual(SourceProvider.detectProvider(from: spotifyURL), .spotify)
    }
    
    func testRSSURLDetection() throws {
        let rssURL1 = "https://feeds.simplecast.com/54nAGcIl"
        let rssURL2 = "https://example.com/podcast.xml"
        let rssURL3 = "https://example.com/rss/feed"
        
        XCTAssertEqual(SourceProvider.detectProvider(from: rssURL1), .rss)
        XCTAssertEqual(SourceProvider.detectProvider(from: rssURL2), .rss)
        XCTAssertEqual(SourceProvider.detectProvider(from: rssURL3), .rss)
    }
    
    func testUnknownURLDetection() throws {
        let unknownURL = "https://example.com/some-page"
        
        XCTAssertEqual(SourceProvider.detectProvider(from: unknownURL), .unknown)
    }
    
    // MARK: - Core Data Tests
    
    func testMediaItemCreation() throws {
        let context = persistenceController.context
        
        let mediaItem = MediaItem(context: context)
        mediaItem.id = UUID()
        mediaItem.title = "Test Video"
        mediaItem.sourceProvider = "YouTube"
        mediaItem.originalURL = "https://www.youtube.com/watch?v=test"
        mediaItem.downloadDate = Date()
        mediaItem.hasVideo = true
        mediaItem.downloadStatus = "completed"
        
        XCTAssertNoThrow(try context.save())
        
        // Verify the item was saved
        let fetchRequest: NSFetchRequest<MediaItem> = MediaItem.fetchRequest()
        let results = try context.fetch(fetchRequest)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Test Video")
        XCTAssertEqual(results.first?.sourceProvider, "YouTube")
        XCTAssertTrue(results.first?.hasVideo ?? false)
    }
    
    @MainActor
    func testLibraryViewModelInitialization() async throws {
        let viewModel = LibraryViewModel(persistenceController: persistenceController)
        
        XCTAssertNil(viewModel.selectedSource)
        XCTAssertEqual(viewModel.sortOption, .downloadDate)
        XCTAssertFalse(viewModel.sortAscending)
        XCTAssertTrue(viewModel.searchText.isEmpty)
        XCTAssertFalse(viewModel.isShowingAddSheet)
        XCTAssertFalse(viewModel.isDownloading)
    }
}

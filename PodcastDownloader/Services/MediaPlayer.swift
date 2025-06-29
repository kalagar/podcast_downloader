//
//  MediaPlayer.swift
//  PodcastDownloader
//
//  Created by AI Assistant on 6/28/25.
//

import Foundation
import AVFoundation
import Combine
import CoreData

/// Handles media playback for both audio and video content
@MainActor
class MediaPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isLoading = false
    @Published var currentItem: MediaItem?
    @Published var playbackMode: PlaybackMode = .audio
    @Published var volume: Float = 1.0 {
        didSet {
            audioPlayer?.volume = volume
            videoPlayer?.volume = volume
        }
    }
    
    private var audioPlayer: AVAudioPlayer?
    private var videoPlayer: AVPlayer?
    private var timeObserver: Any?
    private var playbackPositionTimer: Timer?
    
    enum PlaybackMode {
        case audio
        case video
    }
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    deinit {
        Task { [weak self] in
            await self?.cleanupPlayers()
        }
    }
    
    // MARK: - Public Interface
    
    /// Load and optionally play a media item
    func loadMedia(_ item: MediaItem, mode: PlaybackMode = .audio) async {
        await stopPlayback()
        
        isLoading = true
        currentItem = item
        playbackMode = mode
        
        defer { isLoading = false }
        
        // Use the appropriate file path based on media type
        let filePath = item.hasVideo ? item.localVideoPath : item.localAudioPath
        guard let filePath = filePath,
              let fileURL = URL(string: filePath),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Media file not found: \(filePath ?? "nil")")
            return
        }
        
        do {
            switch mode {
            case .audio:
                try await loadAudioPlayer(url: fileURL)
            case .video:
                try await loadVideoPlayer(url: fileURL)
            }
            
            // Restore last playback position
            if item.lastPlayPosition > 0 {
                await seek(to: item.lastPlayPosition)
            }
            
            updateDuration()
        } catch {
            print("Failed to load media: \(error)")
        }
    }
    
    /// Start or resume playback
    func play() async {
        guard currentItem != nil else { return }
        
        switch playbackMode {
        case .audio:
            audioPlayer?.play()
        case .video:
            videoPlayer?.play()
        }
        
        isPlaying = true
        startTimeTracking()
    }
    
    /// Pause playback
    func pause() async {
        switch playbackMode {
        case .audio:
            audioPlayer?.pause()
        case .video:
            videoPlayer?.pause()
        }
        
        isPlaying = false
        stopTimeTracking()
        await savePlaybackPosition()
    }
    
    /// Stop playback and reset position
    func stopPlayback() async {
        await pause()
        await seek(to: 0)
        currentItem = nil
        cleanupPlayers()
    }
    
    /// Seek to a specific time
    func seek(to time: TimeInterval) async {
        currentTime = time
        
        switch playbackMode {
        case .audio:
            audioPlayer?.currentTime = time
        case .video:
            let cmTime = CMTime(seconds: time, preferredTimescale: 600)
            await videoPlayer?.seek(to: cmTime)
        }
        
        await savePlaybackPosition()
    }
    
    /// Skip forward by specified seconds
    func skipForward(_ seconds: TimeInterval = 30) async {
        let newTime = min(currentTime + seconds, duration)
        await seek(to: newTime)
    }
    
    /// Skip backward by specified seconds
    func skipBackward(_ seconds: TimeInterval = 30) async {
        let newTime = max(currentTime - seconds, 0)
        await seek(to: newTime)
    }
    
    /// Toggle between audio and video modes (for video files)
    func togglePlaybackMode() async {
        guard let item = currentItem,
              item.hasVideo else { return }
        
        let wasPlaying = isPlaying
        let currentPos = currentTime
        
        await pause()
        
        playbackMode = playbackMode == .audio ? .video : .audio
        await loadMedia(item, mode: playbackMode)
        await seek(to: currentPos)
        
        if wasPlaying {
            await play()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        // On macOS, audio session configuration is handled differently
        // AVAudioSession is not available on macOS
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
        #endif
    }
    
    private func loadAudioPlayer(url: URL) async throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.volume = volume
    }
    
    private func loadVideoPlayer(url: URL) async throws {
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        videoPlayer = AVPlayer(playerItem: playerItem)
        videoPlayer?.volume = volume
        
        // Add time observer for video player
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = videoPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }
    }
    
    private func updateDuration() {
        switch playbackMode {
        case .audio:
            duration = audioPlayer?.duration ?? 0
        case .video:
            if let playerItem = videoPlayer?.currentItem {
                duration = playerItem.duration.seconds
            }
        }
    }
    
    private func startTimeTracking() {
        playbackPositionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateCurrentTime()
            }
        }
    }
    
    private func stopTimeTracking() {
        playbackPositionTimer?.invalidate()
        playbackPositionTimer = nil
    }
    
    private func updateCurrentTime() async {
        switch playbackMode {
        case .audio:
            if let player = audioPlayer, player.isPlaying {
                currentTime = player.currentTime
            }
        case .video:
            if let player = videoPlayer,
               let currentItem = player.currentItem,
               player.timeControlStatus == .playing {
                currentTime = currentItem.currentTime().seconds
            }
        }
        
        await savePlaybackPosition()
    }
    
    private func savePlaybackPosition() async {
        guard let item = currentItem else { return }
        
        // Only save if we're more than 5 seconds in and not at the very end
        if currentTime > 5 && currentTime < duration - 5 {
            item.lastPlayPosition = currentTime
            
            // Save to Core Data
            do {
                try item.managedObjectContext?.save()
            } catch {
                print("Failed to save playback position: \(error)")
            }
        }
        
        // Mark as watched if we've reached 90% or the end
        if currentTime >= duration * 0.9 {
            item.isWatched = true
            item.lastWatchedDate = Date()
            
            do {
                try item.managedObjectContext?.save()
            } catch {
                print("Failed to mark as watched: \(error)")
            }
        }
    }
    
    private func cleanupPlayers() {
        stopTimeTracking()
        
        if let timeObserver = timeObserver {
            videoPlayer?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        audioPlayer?.stop()
        audioPlayer = nil
        
        videoPlayer?.pause()
        videoPlayer = nil
        
        currentTime = 0
        duration = 0
    }
}

// MARK: - AVAudioPlayerDelegate

extension MediaPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            
            if flag {
                currentTime = duration
                currentItem?.isWatched = true
                currentItem?.lastWatchedDate = Date()
                
                try? currentItem?.managedObjectContext?.save()
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            isPlaying = false
            print("Audio decode error: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
}

// MARK: - Video Player View

import SwiftUI

/// SwiftUI view for video playback
struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        
        if let player = player {
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = .resizeAspect
            view.layer = playerLayer
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let playerLayer = nsView.layer as? AVPlayerLayer {
            playerLayer.player = player
        }
    }
}

// MARK: - Audio Visualizer View

/// Simple audio visualizer view
struct AudioVisualizerView: View {
    let isPlaying: Bool
    @State private var animationPhase = 0.0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.blue)
                    .frame(width: 4)
                    .frame(height: barHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.1),
                        value: animationPhase
                    )
            }
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            if isPlaying {
                animationPhase += 0.1
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        if !isPlaying {
            return 8
        }
        
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 32
        let phase = animationPhase + Double(index) * 0.5
        let amplitude = sin(phase) * 0.5 + 0.5
        
        return baseHeight + (maxHeight - baseHeight) * amplitude
    }
}

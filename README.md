# PodLoad-Mac

A native macOS downloader & library for video- and audio-first podcasts from YouTube, Spotify, RSS feeds, and more.

## Features

- **Universal Media Support**: Download from YouTube, Spotify podcasts, and RSS feeds
- **Rich Metadata**: Automatically extracts titles, artwork, descriptions, and more
- **Adaptive Playback**: Switch between audio and video playback modes
- **Smart Organization**: Automatic categorization by source provider
- **Advanced Search & Filter**: Find content quickly with powerful search and filtering
- **Progress Tracking**: Resume playback where you left off
- **Background Downloads**: Download multiple items with progress tracking

## System Requirements

- macOS 14.0 or later
- Xcode 15.0 or later (for building from source)

## Building and Running

### Quick Start

```bash
make run
```

This will build and launch the application.

### Development

```bash
make dev
```

Opens the project in Xcode for development.

### Other Commands

```bash
make build    # Build the application
make test     # Run unit tests
make clean    # Clean build artifacts
make help     # Show all available commands
```

## Usage

1. **Adding Media**: Press ⌘N or click "Add" to paste a URL from YouTube, Spotify, or RSS feed
2. **Browsing Library**: Use the sidebar to filter by source, or search across all content
3. **Playback**: Double-click any item to open the detail view with integrated player
4. **Organization**: Sort by title, date, duration, or watched status

## Supported URLs

- **YouTube**: `https://www.youtube.com/watch?v=...`
- **Spotify Podcasts**: `https://podcasters.spotify.com/pod/show/...`
- **RSS Feeds**: Any valid podcast RSS feed URL

## Architecture

The application follows a clean MVVM architecture with:

- **Models**: Core Data entities for persistent storage
- **ViewModels**: Observable classes managing UI state and business logic
- **Services**: Download and metadata extraction services
- **Views**: SwiftUI views for the user interface

### Key Components

- `LibraryViewModel`: Main view model managing the media library
- `DownloadService`: Handles media downloads and metadata extraction
- `PersistenceController`: Core Data stack management
- `MediaItem`: Core Data entity representing downloaded media

## Provider Plugin System

The application is designed to support additional media providers. To add a new provider:

1. Add a case to the `SourceProvider` enum
2. Implement metadata extraction in `DownloadService`
3. Add URL detection logic to `SourceProvider.detectProvider()`

## Storage

- **Database**: Core Data SQLite store in `~/Library/Application Support/PodLoad/`
- **Media Files**: Downloaded content in `~/Library/Application Support/PodLoad/Media/{source}/{id}/`
- **Settings**: App preferences stored using `@AppStorage`

## Testing

The project includes unit tests covering:

- Metadata extraction
- URL provider detection
- Core Data operations
- Download service functionality

Run tests with:

```bash
make test
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Roadmap

- [ ] Playlist creation and management
- [ ] Global keyboard shortcuts
- [ ] System notifications
- [ ] iCloud sync
- [ ] Automatic RSS refresh
- [ ] Transcript generation (Whisper integration)
- [ ] iOS companion app with handoff

## Support

For issues and feature requests, please use the GitHub issue tracker.

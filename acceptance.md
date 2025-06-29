📋 Prompt for the AI agent

Project name: “PodLoad-Mac” — a native macOS downloader & library for video- and audio-first podcasts (YouTube, Spotify, RSS, etc.)
Goal: Build a polished, sandbox-compliant, Swift-based macOS app that lets me paste a link to any supported service (YouTube video, Spotify episode, generic podcast RSS item, etc.), automatically downloads the media, and maintains an offline library with rich filtering, search, and playback for both audio and video variants.

⸻

1. Core user stories (“must-haves”)
    1. Paste & go
As a user, when I press ⌘N or click “Add”, a sheet appears where I paste a URL. After pressing “Download” the app: (a) recognises the provider, (b) fetches metadata (title, channel/show, duration, artwork, publish date, description, tags), (c) downloads the highest-quality audio and, when applicable, the highest-quality video stream, and (d) inserts a new record into the local library.
    1. Categorised library
Items are automatically grouped by “Source” (e.g. YouTube, Spotify, RSS) in a sidebar. I can also see an “All” view.
    1. Sort, filter, search
At the top of the list I can:
    •    Sort by title, show/channel, publish date, download date, duration, watched/unwatched.
    •    Filter by source, media type (audio-only, video-capable), tags, or a free-text query that matches title/description.
    1. Detail view & playback
When I double-click or press ⏎ on an item, a split-pane detail view opens:
    •    Left: artwork thumbnail, metadata table, “Open original on web” link, file-size, storage path.
    •    Right: an adaptive player: choose Audio (embedded AVAudioPlayerNode) or Video (AVPlayerLayer).
    •    Remember last play position and “watched” state.
    1. Reliability
    •    Background-safe downloads with progress bars, pause/resume, cancel, and error handling.
    •    Gracefully recover if a provider changes its URL scheme; expose clear error messages.
    •    If the same URL is pasted twice, prompt to overwrite, skip, or keep both.

⸻

2. Nice-to-haves (if time permits)

Feature    Notes
Playlist builder    Drag-and-drop items into custom playlists; continuous audio playback.
Global keyboard shortcuts    e.g. ⌥⌘V to paste-and-download immediately.
Notifications    System notification when downloads finish.
iCloud sync    Optional Core Data iCloud container so the library syncs across Macs.
Automatic RSS refresh    For podcast feeds, poll every X hours and queue new episodes.

⸻

3. Technical expectations

Layer    Requirements
Language & UI    Swift 5.10 + SwiftUI (macOS 14 SDK). Use @Observable / @StateObject for data models.
Architecture    Clean MVVM or TCA; async/await throughout; Combine where helpful.
Downloads    Bundle yt-dlp (or HLS-capable custom downloader) via a bundled binary or SPM package. Provide an abstraction so new providers can be plugged in.
Metadata    YouTube → yt-dlp JSON; Spotify → Spotify Web API (Client Credentials flow, no user auth); RSS → feedparser.
Storage    Core Data with lightweight migrations; binary files stored in ~/Library/Application Support/PodLoad/Media/{source}/{id}/.
Playback    AVFoundation; switch between AVPlayer (video) and AVAudioEngine (audio) seamlessly.
Persistence    Persist sort/filter/search state using AppStorage.
Sandboxing / notarization    Fully sandboxed; Hardened Runtime; prepare for Mac App Store notarization but distribution can be outside MAS.

⸻

4. UX / UI spec

Window (Resizable, min 1024×640)
 ├── Toolbar
 │    [Add] [Delete] [Sort ▾] [Filter ▾] [Search Field─────────────────────]
 ├── Sidebar (List)
 │    • All
 │    • YouTube
 │    • Spotify
 │    • RSS
 │    • <future sources…>
 └── Main Content
      ├── Table/List view
      │     Columns: Title | Show/Channel | Duration | Type | Date
      └── Optional SplitDetail
            ├── Metadata Card
            └── Player (Audio or Video selector)

⸻

5. Acceptance criteria / “Definition of Done”
    1. Running make run (or opening the Xcode project) launches the app with no build warnings.
    2. Paste the sample URL list (see below) and verify that every item downloads, is categorised, displays metadata, and plays back correctly.
    3. Unit tests ≥ 80 % coverage on the parsing/downloader layer.
    4. App plays 4k video smoothly on an Apple Silicon Mac; memory ≤ 200 MB idle.
    5. Passes Apple’s notarisation in CI.

Sample URLs for tests:
    •    <https://www.youtube.com/watch?v=dQw4w9WgXcQ>
    •    <https://podcasters.spotify.com/pod/show/lexfridman/episodes/1-Meta>...
    •    <https://feeds.simplecast.com/54nAGcIl> (RSS)

⸻

6. Deliverables
    1. Xcode project (Swift Package-friendly).
    2. README with build instructions, provider plug-in guide, and FAQ.
    3. Developer documentation (DocC) for major modules.
    4. Fastlane lane for code-signing, notarisation, and dmg creation.
    5. Unit & UI tests runnable in GitHub Actions.

⸻

7. Stretch ideas for v2+
    •    In-app mini-transcript (auto-speech-to-text via Whisper).
    •    Smart “Continue Listening” widget in macOS Notification Centre.
    •    Hand-off to iOS companion app (share playback position).
    •    Automatic chapter extraction from YouTube description.

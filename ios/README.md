# ClassMusic (iOS)

SwiftUI, iOS 26.0 minimum (Liquid Glass — `.glassEffect` — requires it),
MVVM. Personal use / TestFlight internal testing only, matching the
`com.classmate.*` bundle ID convention and NNFD7CKGLG team from ClassMate-Notes.

## First-time setup

```bash
brew install xcodegen   # if not already installed
cd ios
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
# edit Secrets.xcconfig: YOUTUBE_API_KEY, BACKEND_BASE_URL, BACKEND_API_KEY
xcodegen generate
open ClassMusic.xcodeproj
```

`ClassMusic.xcodeproj` is generated, not committed — `project.yml` is the
source of truth. Re-run `xcodegen generate` after adding/removing files or
changing `project.yml` (new Swift files under an existing folder are picked
up automatically by Xcode's synchronized groups, but target/build-setting
changes need a regenerate).

`Config/Secrets.xcconfig` is gitignored. Note the `$()` in URL values
(`http:/$()/localhost:8123`) — xcconfig treats a bare `//` as a comment,
so the scheme separator has to be split up like that or the URL silently
truncates.

## Running locally

Start the backend first (see `../backend/README.md`), then build/run
`ClassMusic` on a simulator or device. `#if DEBUG` in `SearchView`/
`ContentView` adds:
- A "Test Playback" button (plays a known-good video ID directly, useful
  without a YouTube API key configured yet).
- `SIMCTL_CHILD_UITEST_AUTOPLAY=1` env var: auto-plays that track on launch.
- `SIMCTL_CHILD_UITEST_LIBRARY=1` env var: exercises playlist/favorite/queue
  creation through SwiftData directly and switches to the Library tab.

Both are how this app was actually verified end-to-end in an environment
without XCUITest/assistive-access for simulating taps — e.g.:
```bash
SIMCTL_CHILD_UITEST_AUTOPLAY=1 xcrun simctl launch <device-id> com.classmate.music
```

## Architecture

- `Network/` — `YouTubeSearchClient` (YouTube Data API v3, direct from the
  app) and `ResolveClient` (talks to the backend's `/resolve`).
- `Playback/` — `PlaybackManager` (AVPlayer + background audio session) and
  `NowPlayingCoordinator` (MPNowPlayingInfoCenter/MPRemoteCommandCenter),
  kept as separate concerns; `PlaybackManager` also writes the widget's
  shared snapshot and listens for Darwin-notification commands from the
  widget/CarPlay processes.
- `Models/` — SwiftData (`Song`, `Playlist`/`PlaylistItem`,
  `PlaybackQueue`/`QueueItem`) plus `QueueStore` (queue persistence/advance
  logic) and `SongRepository` (upserts a persisted `Song` from a transient
  search result).
- `Views/` — SwiftUI, MVVM-lite (SwiftData's `@Query` covers most of what a
  separate ViewModel would otherwise do).
- `CarPlay/CarPlaySceneDelegate` — separate UIKit scene delegate; reaches
  shared state via `PlaybackManager.shared` / `QueueStore.shared` /
  `ModelContainerHolder.shared` rather than the SwiftUI environment.
- `../ClassMusicWidget/` — WidgetKit extension, reads `Shared/
  NowPlayingSnapshot` (JSON in the App Group's UserDefaults + a cached
  artwork JPEG) rather than querying SwiftData or the network directly.
- `Shared/` — code used by both the app and widget targets.

## CarPlay

The `com.apple.developer.carplay-audio` entitlement is commented out in
`project.yml` — confirmed by testing that archiving hard-fails without
Apple actually having granted it to the account
(https://developer.apple.com/contact/carplay/). Local simulator builds work
fine without it since no provisioning profile is involved there. Once
granted, uncomment it in `project.yml` and re-run `xcodegen generate`.

CarPlay itself (the actual `CPTemplateApplicationSceneDelegate` connecting
and rendering templates) needs either a physical CarPlay head unit or
Xcode's Simulator app → I/O → External Displays → CarPlay, neither of which
this was built against — verified by build success and code review only.

## TestFlight archive/export

`./archive.sh` runs the exact commands validated against the real
NNFD7CKGLG account on this machine: `xcodebuild archive` (Release config,
`generic/platform=iOS`) then `xcodebuild -exportArchive` with
`ExportOptions.plist` (method `app-store-connect`). `-allowProvisioningUpdates`
on both steps lets `xcodebuild` register the App Group capability for the
`com.classmate.music`/`com.classmate.music.widget` App IDs via the Developer
Portal API itself, rather than needing a one-time manual Xcode GUI setup
step first.

Confirmed on the resulting `.ipa`: both the app and widget extension are
Apple Distribution-signed (not development), team NNFD7CKGLG, App Group
entitlement present on both, `beta-reports-active: true` (TestFlight-ready).
Upload the result with Transporter.app or `xcrun altool --upload-app`.

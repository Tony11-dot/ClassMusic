# ClassMusic

Personal iOS music app — search YouTube, play audio in the background with
full lock screen/Control Center/CarPlay/widget integration. Not intended for
public App Store release (yt-dlp-based backend violates YouTube's ToS for
general distribution); personal use / TestFlight internal testing only.

- [`backend/`](backend/README.md) — FastAPI + yt-dlp service that resolves a
  YouTube video ID to a direct, AVPlayer-playable AAC stream URL.
- [`ios/`](ios/README.md) — the SwiftUI app, widget extension, and CarPlay
  scene. Search hits the YouTube Data API v3 directly from the app; only
  audio resolution goes through the backend.

Bundle IDs follow the `com.classmate.*` convention and NNFD7CKGLG team from
the ClassMate-Notes app.

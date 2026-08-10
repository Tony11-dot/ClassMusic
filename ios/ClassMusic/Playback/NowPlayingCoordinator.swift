import Foundation
import MediaPlayer
import UIKit
import os

private let logger = Logger(subsystem: "com.classmate.music", category: "NowPlaying")

/// Owns MPNowPlayingInfoCenter + MPRemoteCommandCenter so PlaybackManager
/// doesn't have to know about MediaPlayer directly. PlaybackManager calls
/// `update(...)` on every state change; remote commands (lock screen,
/// Control Center, CarPlay, AirPods) come back in through the closures.
@MainActor
final class NowPlayingCoordinator {
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?
    var onSeek: ((TimeInterval) -> Void)?

    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var artworkCache: [String: MPMediaItemArtwork] = [:]
    private var artworkLoadTask: Task<Void, Never>?

    init() {
        configureRemoteCommands()
    }

    private func configureRemoteCommands() {
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.onPlay?()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.onPause?()
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.onNextTrack?()
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.onPreviousTrack?()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.onSeek?(event.positionTime)
            return .success
        }

        // Not applicable to a music queue (these are for podcast/audiobook
        // style scrubbing) — explicitly off so Control Center doesn't show
        // them as disabled-looking buttons.
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
    }

    /// `song` nil clears Now Playing entirely (nothing loaded yet).
    func update(song: Song?, duration: TimeInterval, elapsed: TimeInterval, rate: Float) {
        guard let song else {
            infoCenter.nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: rate,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]

        if let artwork = artworkCache[song.id] {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        infoCenter.nowPlayingInfo = info
        logger.info("nowPlayingInfo: title=\(song.title) artist=\(song.artist) duration=\(duration) elapsed=\(elapsed) rate=\(rate) hasArtwork=\(self.artworkCache[song.id] != nil)")

        if artworkCache[song.id] == nil, let url = song.thumbnailURL {
            loadArtwork(for: song.id, url: url)
        }
    }

    private func loadArtwork(for songId: String, url: URL) {
        artworkLoadTask?.cancel()
        artworkLoadTask = Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data)
            else { return }
            guard let self, !Task.isCancelled else { return }
            // MediaPlayer calls this requestHandler from an arbitrary
            // background queue when it serializes Now Playing info for
            // Control Center/the lock screen. Without @Sendable here, Swift
            // infers MainActor isolation (this closure is written inside a
            // @MainActor class) and inserts a runtime check that crashes
            // the moment MediaPlayer calls it off the main thread.
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { @Sendable _ in image }
            self.artworkCache[songId] = artwork
            logger.info("artwork loaded for \(songId): \(image.size.width)x\(image.size.height)")
            // Re-apply so the lock screen picks up the artwork that just
            // finished loading, without clobbering elapsed/rate set since.
            if var info = self.infoCenter.nowPlayingInfo {
                info[MPMediaItemPropertyArtwork] = artwork
                self.infoCenter.nowPlayingInfo = info
            }
        }
    }
}

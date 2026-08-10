import AVFoundation
import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.classmate.music", category: "Playback")

@Observable
@MainActor
final class PlaybackManager {
    private(set) var currentSong: Song?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isBuffering = false
    private(set) var loadError: String?

    /// Fired when the current item plays to the end. Queue advance logic
    /// (stage 4) hooks in here instead of PlaybackManager knowing about
    /// PlaybackQueue directly.
    var onTrackFinished: (() -> Void)?

    private let player = AVPlayer()
    private let resolveClient: ResolveClient
    // deinit is always nonisolated, even on a @MainActor class, so cleanup
    // there can't touch MainActor-isolated storage — these two are the only
    // state deinit needs, and PlaybackManager's single-threaded lifecycle
    // makes touching them off-actor safe.
    private nonisolated(unsafe) var timeObserver: Any?
    private nonisolated(unsafe) var itemEndObserver: NSObjectProtocol?

    init(resolveClient: ResolveClient = ResolveClient()) {
        self.resolveClient = resolveClient
        configureAudioSession()
        observeTime()
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let itemEndObserver { NotificationCenter.default.removeObserver(itemEndObserver) }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            loadError = "Audio session setup failed: \(error.localizedDescription)"
        }
    }

    private func observeTime() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds.isFinite ? time.seconds : 0
            if let itemDuration = self.player.currentItem?.duration.seconds, itemDuration.isFinite {
                self.duration = itemDuration
            }
        }
    }

    @MainActor
    func play(song: Song) async {
        loadError = nil
        isBuffering = true
        currentSong = song
        currentTime = 0
        duration = song.duration ?? 0

        do {
            let resolved = try await resolveClient.resolve(videoId: song.id)
            logger.info("resolved \(song.id): \(resolved.streamURL.absoluteString.prefix(80))...")
            if song.duration == nil, let resolvedDuration = resolved.duration {
                song.duration = resolvedDuration
                duration = resolvedDuration
            }

            let item = AVPlayerItem(url: resolved.streamURL)
            attachEndObserver(to: item)
            player.replaceCurrentItem(with: item)
            player.play()
            isPlaying = true
            logger.info("playing \(song.id), player.rate=\(self.player.rate)")
        } catch {
            logger.error("resolve/play failed for \(song.id): \(error.localizedDescription)")
            loadError = error.localizedDescription
        }
        isBuffering = false
    }

    private func attachEndObserver(to item: AVPlayerItem) {
        if let itemEndObserver {
            NotificationCenter.default.removeObserver(itemEndObserver)
        }
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
            self?.onTrackFinished?()
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func resume() {
        guard currentSong != nil else { return }
        player.play()
        isPlaying = true
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func seek(to time: TimeInterval) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
    }
}

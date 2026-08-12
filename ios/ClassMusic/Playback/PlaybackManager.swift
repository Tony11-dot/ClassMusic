import AVFoundation
import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.classmate.music", category: "Playback")

@Observable
@MainActor
final class PlaybackManager {
    /// Looked up (not captured) from inside the Darwin notification
    /// callback below, since that callback must be a capture-free
    /// @convention(c) closure — see observeWidgetCommands().
    static weak var shared: PlaybackManager?

    private(set) var currentSong: Song?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isBuffering = false
    private(set) var loadError: String?

    /// Fired when the current item plays to the end, or when the lock
    /// screen/Control Center/CarPlay next-previous buttons are used. Queue
    /// advance logic (stage 4) hooks in here instead of PlaybackManager
    /// knowing about PlaybackQueue directly.
    var onTrackFinished: (() -> Void)?
    var onSkipNext: (() -> Void)?
    var onSkipPrevious: (() -> Void)?

    private let player = AVPlayer()
    private let resolveClient: ResolveClient
    private let nowPlaying = NowPlayingCoordinator()
    // deinit is always nonisolated, even on a @MainActor class, so cleanup
    // there can't touch MainActor-isolated storage — these two are the only
    // state deinit needs, and PlaybackManager's single-threaded lifecycle
    // makes touching them off-actor safe.
    private nonisolated(unsafe) var timeObserver: Any?
    private nonisolated(unsafe) var itemEndObserver: NSObjectProtocol?
    private nonisolated(unsafe) var itemFailureObserver: NSObjectProtocol?
    private nonisolated(unsafe) var itemStatusObservation: NSKeyValueObservation?
    private var readyTimeoutTask: Task<Void, Never>?

    init(resolveClient: ResolveClient = ResolveClient()) {
        self.resolveClient = resolveClient
        configureAudioSession()
        observeTime()
        configureRemoteCommands()
        observeInterruptions()
        Self.shared = self
        observeWidgetCommands()
    }

    /// Widget buttons run in the widget extension process and can't touch
    /// this instance's AVPlayer directly, so they post a Darwin
    /// notification (see WidgetCommand) instead. This only works while the
    /// app process is alive — which it is throughout playback, thanks to
    /// the background audio mode — not if it's been fully terminated.
    private func observeWidgetCommands() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        for command in [WidgetCommand.togglePlayPause, .skipNext, .skipPrevious] {
            CFNotificationCenterAddObserver(center, nil, { _, _, name, _, _ in
                guard let name, let command = WidgetCommand(rawValue: name.rawValue as String) else { return }
                Task { @MainActor in
                    PlaybackManager.shared?.handleWidgetCommand(command)
                }
            }, command.darwinName, nil, .deliverImmediately)
        }
    }

    private func handleWidgetCommand(_ command: WidgetCommand) {
        switch command {
        case .togglePlayPause: togglePlayPause()
        case .skipNext: onSkipNext?()
        case .skipPrevious: onSkipPrevious?()
        }
    }

    /// Without this, a phone call silences AVPlayer but PlaybackManager
    /// still thinks it's playing — the lock screen shows a pause button
    /// that does nothing useful and Control Center's state is just wrong.
    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }

            switch type {
            case .began:
                self.pause()
            case .ended:
                let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                if AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                    self.resume()
                }
            @unknown default:
                break
            }
        }
    }

    private func configureRemoteCommands() {
        nowPlaying.onPlay = { [weak self] in self?.resume() }
        nowPlaying.onPause = { [weak self] in self?.pause() }
        nowPlaying.onNextTrack = { [weak self] in self?.onSkipNext?() }
        nowPlaying.onPreviousTrack = { [weak self] in self?.onSkipPrevious?() }
        nowPlaying.onSeek = { [weak self] time in self?.seek(to: time) }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let itemEndObserver { NotificationCenter.default.removeObserver(itemEndObserver) }
        if let itemFailureObserver { NotificationCenter.default.removeObserver(itemFailureObserver) }
        itemStatusObservation?.invalidate()
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
        // queue: .main guarantees this fires on the main queue, so
        // assumeIsolated is safe — Swift just can't infer that statically
        // from a plain (CMTime) -> Void closure type.
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                if let itemDuration = self.player.currentItem?.duration.seconds, itemDuration.isFinite {
                    self.duration = itemDuration
                }
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

            let asset = AVURLAsset(url: resolved.streamURL, options: [
                "AVURLAssetHTTPHeaderFieldsKey": resolved.streamHeaders,
            ])
            let item = AVPlayerItem(asset: asset)
            attachObservers(to: item)
            player.replaceCurrentItem(with: item)
            player.play()
            isPlaying = true
            nowPlaying.update(song: song, duration: duration, elapsed: 0, rate: 1)
            logger.info("playing \(song.id), player.rate=\(self.player.rate)")
        } catch {
            logger.error("resolve/play failed for \(song.id): \(error.localizedDescription)")
            loadError = error.localizedDescription
            isBuffering = false
        }
    }

    /// Wires up everything needed so a broken stream surfaces as `loadError`
    /// instead of leaving the UI stuck on a spinner forever: end-of-item,
    /// mid-playback failures, initial load failures (KVO on `.status`), and
    /// a timeout in case the item never resolves either way.
    private func attachObservers(to item: AVPlayerItem) {
        if let itemEndObserver {
            NotificationCenter.default.removeObserver(itemEndObserver)
        }
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isPlaying = false
                self?.onTrackFinished?()
            }
        }

        if let itemFailureObserver {
            NotificationCenter.default.removeObserver(itemFailureObserver)
        }
        itemFailureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            MainActor.assumeIsolated {
                self?.handleLoadFailure(error?.localizedDescription ?? "Playback failed")
            }
        }

        itemStatusObservation?.invalidate()
        // AVPlayerItem's KVO callbacks aren't guaranteed to land on the main
        // queue, unlike the notification observers above.
        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .failed:
                    self.handleLoadFailure(item.error?.localizedDescription ?? "This track couldn't be played")
                case .readyToPlay:
                    self.isBuffering = false
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        readyTimeoutTask?.cancel()
        readyTimeoutTask = Task { [weak self, weak item] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self, let item, item.status != .readyToPlay else { return }
            self.handleLoadFailure("Stream timed out — check your connection and try again")
        }
    }

    private func handleLoadFailure(_ message: String) {
        loadError = message
        isBuffering = false
        isPlaying = false
        player.pause()
    }

    func pause() {
        player.pause()
        isPlaying = false
        nowPlaying.update(song: currentSong, duration: duration, elapsed: currentTime, rate: 0)
    }

    func resume() {
        guard currentSong != nil else { return }
        player.play()
        isPlaying = true
        nowPlaying.update(song: currentSong, duration: duration, elapsed: currentTime, rate: 1)
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func clearLoadError() {
        loadError = nil
    }

    func seek(to time: TimeInterval) {
        // AVPlayer explicitly does not guarantee this completion runs on
        // any particular queue, so hop back to the main actor properly
        // rather than assuming (unlike the two observers above, which do
        // specify queue: .main).
        player.seek(to: CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.nowPlaying.update(song: self.currentSong, duration: self.duration, elapsed: time, rate: self.isPlaying ? 1 : 0)
            }
        }
    }
}

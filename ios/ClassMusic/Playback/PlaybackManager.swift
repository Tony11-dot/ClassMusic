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

    /// Bumped on every user/queue-initiated `play(song:)` call (never on an
    /// internal retry), so an in-flight retry can tell whether it's still
    /// for the track actually wanted — without this, a retry sleeping after
    /// a transient failure could clobber a song the user has since skipped
    /// to when it finally fires.
    private var loadGeneration = 0
    /// Resolve failures and AVPlayer load failures (bad stream URL blip,
    /// backend cold start, a dropped connection mid-handshake) are usually
    /// transient — the same request often succeeds seconds later. Spotify/
    /// YouTube-style "just plays" behavior means eating a couple of those
    /// silently before ever bothering the user with an alert.
    private static let maxLoadRetries = 2
    private var activeSong: Song?
    private var activeRetryCount = 0
    private var activeGeneration = 0

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

    /// Fire-and-forget ping to wake a sleeping free-tier backend instance as
    /// early as possible (app launch) instead of only on the first play tap
    /// — Render's free tier cold-starts in 15-30s, so a tap that triggers
    /// that cold start itself just sits there looking broken. Called from
    /// ContentView's launch `.task`, not awaited there, so it overlaps with
    /// the rest of startup instead of delaying it.
    func prewarm() async {
        _ = await resolveClient.wake()
    }

    @MainActor
    func play(song: Song, retryCount: Int = 0, generation: Int? = nil, resumeAt: TimeInterval? = nil) async {
        let generation = generation ?? {
            loadGeneration += 1
            return loadGeneration
        }()

        loadError = nil
        isBuffering = true
        currentSong = song
        currentTime = 0
        duration = song.duration ?? 0

        do {
            let resolved = try await resolveClient.resolve(videoId: song.id)
            logger.info("resolved \(song.id): \(resolved.streamURL.absoluteString.prefix(80))...")
            song.lastPlayedAt = .now
            if song.duration == nil, let resolvedDuration = resolved.duration {
                song.duration = resolvedDuration
                duration = resolvedDuration
            }

            let asset = AVURLAsset(url: resolved.streamURL, options: [
                "AVURLAssetHTTPHeaderFieldsKey": resolved.streamHeaders,
                // Precise duration/timing forces AVFoundation to index the
                // full sample table before reporting readyToPlay — for a
                // 30-60min combined-format file (see the duration-scaled
                // timeout below) that's a lot of extra scanning for
                // precision this app never uses (no frame-accurate
                // scrubbing). We already have the real duration from the
                // resolve API, so approximate timing costs nothing here and
                // meaningfully cuts startup latency on long tracks.
                AVURLAssetPreferPreciseDurationAndTimingKey: false,
            ])
            let item = AVPlayerItem(asset: asset)
            // Default buffering heuristics scale their "how much to
            // buffer before playing" estimate with the asset's total
            // size/duration, which is exactly backwards for a 90MB+ long
            // track on a slow connection — it makes the wait *longer* right
            // when speed matters most. A small explicit forward-buffer
            // target plus disabling the adaptive wait makes playback start
            // as soon as a few seconds are actually buffered.
            item.preferredForwardBufferDuration = 5
            player.automaticallyWaitsToMinimizeStalling = false
            // Long-form content (full concerts, DJ sets) frequently only has
            // a heavy combined video+audio stream available (YouTube
            // withholds the small audio-only format for some videos even
            // from the authenticated fallback) — a 90-minute show can mean
            // a 90MB+ file just to reach readyToPlay, which a flat 45s
            // budget doesn't leave enough room for on a slow connection.
            // Scales gently: a typical 3-4min song barely moves off the
            // 45s floor, a 30min video gets roughly a minute more.
            let timeoutSeconds = 45.0 + min(60.0, duration / 30.0)
            attachObservers(to: item, song: song, retryCount: retryCount, generation: generation, timeoutSeconds: timeoutSeconds)
            player.replaceCurrentItem(with: item)
            player.play()
            isPlaying = true
            if let resumeAt, resumeAt > 1 {
                seek(to: resumeAt)
            }
            nowPlaying.update(song: song, duration: duration, elapsed: resumeAt ?? 0, rate: 1)
            logger.info("playing \(song.id), player.rate=\(self.player.rate)")
        } catch {
            logger.warning("resolve failed for \(song.id) (attempt \(retryCount + 1)): \(error.localizedDescription)")
            await retryOrFail(song: song, retryCount: retryCount, generation: generation, resumeAt: resumeAt, message: error.localizedDescription)
        }
    }

    /// Shared by both failure paths above (resolve throwing, and AVPlayer's
    /// own load failures via `handleLoadFailure`): retry the same song a
    /// couple times with a short backoff before giving up and surfacing
    /// `loadError`. Bails out quietly — no alert — if a newer `play(song:)`
    /// call has superseded this one while the retry was waiting. `resumeAt`
    /// carries the playhead position through a mid-playback failure (a long
    /// concert dying at minute 45 should retry into minute 45, not restart
    /// from zero).
    @MainActor
    private func retryOrFail(song: Song, retryCount: Int, generation: Int, resumeAt: TimeInterval?, message: String) async {
        guard generation == loadGeneration else { return }
        guard retryCount < Self.maxLoadRetries else {
            loadError = message
            isBuffering = false
            isPlaying = false
            return
        }
        try? await Task.sleep(for: .seconds(1.5))
        guard generation == loadGeneration else { return }
        await play(song: song, retryCount: retryCount + 1, generation: generation, resumeAt: resumeAt)
    }

    /// Wires up everything needed so a broken stream surfaces as `loadError`
    /// instead of leaving the UI stuck on a spinner forever: end-of-item,
    /// mid-playback failures, initial load failures (KVO on `.status`), and
    /// a timeout in case the item never resolves either way. `song`/
    /// `retryCount`/`generation` are stashed so `handleLoadFailure` (invoked
    /// from these observers, not from `play` itself) knows what to retry.
    private func attachObservers(to item: AVPlayerItem, song: Song, retryCount: Int, generation: Int, timeoutSeconds: TimeInterval) {
        activeSong = song
        activeRetryCount = retryCount
        activeGeneration = generation

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
            // 20s was too tight: the cookie-authenticated fallback path
            // (bot-walled videos) alone takes ~20-25s server-side just to
            // resolve, before AVPlayer even starts buffering the proxied
            // stream — this was killing genuinely-in-progress loads and
            // surfacing them as "Stream timed out" even though they would
            // have started playing seconds later. See timeoutSeconds above
            // for why this isn't a flat number.
            try? await Task.sleep(for: .seconds(timeoutSeconds))
            guard !Task.isCancelled, let self, let item, item.status != .readyToPlay else { return }
            self.handleLoadFailure("Stream timed out — check your connection and try again")
        }
    }

    private func handleLoadFailure(_ message: String) {
        player.pause()
        isPlaying = false
        guard let song = activeSong else {
            loadError = message
            isBuffering = false
            return
        }
        // currentTime > 1 means this item had actually started playing
        // (a mid-stream stall/drop), so the retry should resume there
        // instead of restarting a long track from zero.
        let resumeAt = currentTime > 1 ? currentTime : nil
        let retryCount = activeRetryCount
        let generation = activeGeneration
        Task { [weak self] in
            await self?.retryOrFail(song: song, retryCount: retryCount, generation: generation, resumeAt: resumeAt, message: message)
        }
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

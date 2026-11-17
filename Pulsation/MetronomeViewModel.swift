import AVFoundation
import Combine
import WatchKit

enum HapticIntensity: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: Self { self }

    var arcCount: Int {
        switch self {
        case .low: DesignSystem.Haptics.lowArcCount
        case .medium: DesignSystem.Haptics.mediumArcCount
        case .high: DesignSystem.Haptics.highArcCount
        }
    }

    var title: String {
        switch self {
        case .low: L10n.hapticIntensityLow
        case .medium: L10n.hapticIntensityMedium
        case .high: L10n.hapticIntensityHigh
        }
    }

    var watchKitType: WKHapticType {
        switch self {
        case .low: .click
        case .medium: .start
        case .high: .directionUp
        }
    }
}

@MainActor
final class MetronomeViewModel: ObservableObject {
    @Published var bpm = DesignSystem.Tempo.initialBPM
    @Published var beatsPerBar = DesignSystem.Tempo.initialBeatsPerBar
    @Published private(set) var isPlaying = false
    @Published private(set) var beat = DesignSystem.Tempo.firstBeatIndex
    @Published private(set) var hapticPulseCount = DesignSystem.Haptics.initialPulseCount
    @Published var mode: PracticeMode = .free
    @Published private(set) var elapsedSeconds = DesignSystem.Tempo.initialElapsedSeconds
    @Published private(set) var isSoundEnabled = DesignSystem.Preferences.defaultEnabled
    @Published private(set) var soundVolume = DesignSystem.Audio.defaultVolume
    @Published private(set) var isHapticsEnabled = DesignSystem.Preferences.defaultEnabled
    @Published private(set) var selectedHapticIntensity = DesignSystem.Haptics.defaultIntensity

    private var pulseTask: Task<Void, Never>?
    private var pulseGeneration = 0
    private var hapticPreviewTask: Task<Void, Never>?
    private var phaseStart = Date()
    private var baseBPM = DesignSystem.Tempo.initialBPM
    private var lastTap = Date.distantPast
    private let audioPlayer = AudioClickPlayer()
    private var audioSessionIsReady = false
    private var audioSessionGeneration = 0

    enum PracticeMode: CaseIterable, Identifiable {
        case free
        case ramp
        case silence

        var id: Self { self }

        var title: String {
            switch self {
            case .free: L10n.modeFree
            case .ramp: L10n.modeRamp
            case .silence: L10n.modeSilence
            }
        }

        var subtitle: String {
            switch self {
            case .free: L10n.modeFreeDescription
            case .ramp: L10n.modeRampDescription
            case .silence: L10n.modeSilenceDescription
            }
        }

        var badge: String? {
            switch self {
            case .free: nil
            case .ramp: L10n.rampBadge
            case .silence: L10n.silenceBadge
            }
        }
    }

    init() {
        if let savedSoundPreference = UserDefaults.standard.object(forKey: DesignSystem.Preferences.soundEnabledKey) as? Bool {
            isSoundEnabled = savedSoundPreference
        }
        if let savedSoundVolume = UserDefaults.standard.object(forKey: DesignSystem.Preferences.soundVolumeKey) as? Double {
            soundVolume = min(
                DesignSystem.Audio.maximumVolume,
                max(DesignSystem.Audio.minimumVolume, savedSoundVolume)
            )
        }
        if let savedHapticsPreference = UserDefaults.standard.object(forKey: DesignSystem.Preferences.hapticsEnabledKey) as? Bool {
            isHapticsEnabled = savedHapticsPreference
        }
        if let savedHapticIntensity = UserDefaults.standard.string(forKey: DesignSystem.Preferences.hapticIntensityKey),
           let intensity = HapticIntensity(rawValue: savedHapticIntensity) {
            selectedHapticIntensity = intensity
        }
        audioPlayer.setVolume(Float(soundVolume))
    }

    func start() {
        guard !isPlaying else { return }
        baseBPM = bpm
        elapsedSeconds = DesignSystem.Tempo.initialElapsedSeconds
        beat = DesignSystem.Tempo.firstBeatIndex

        isPlaying = true
        hapticPreviewTask?.cancel()
        hapticPreviewTask = nil
        if isSoundEnabled {
            activateAudioSession { [weak self] in self?.beginPulseTimer() }
        } else {
            beginPulseTimer()
        }
    }

    private func beginPulseTimer() {
        guard isPlaying, pulseTask == nil else { return }
        phaseStart = Date()
        pulseGeneration += 1
        let generation = pulseGeneration
        let clock = ContinuousClock()

        pulseTask = Task(priority: .high) { [weak self] in
            do {
                try await clock.sleep(for: DesignSystem.Timing.hapticInteractionSeparation)
            } catch {
                self?.finishPulseTask(generation: generation)
                return
            }

            var nextDeadline = clock.now

            while !Task.isCancelled {
                guard let interval = self?.playBeat(for: generation) else { break }
                nextDeadline = nextDeadline.advanced(by: interval)
                if nextDeadline < clock.now {
                    nextDeadline = clock.now.advanced(by: interval)
                }

                do {
                    try await clock.sleep(
                        until: nextDeadline,
                        tolerance: DesignSystem.Timing.pulseSleepTolerance
                    )
                } catch {
                    break
                }
            }

            self?.finishPulseTask(generation: generation)
        }
    }

    func stop() {
        pulseGeneration += 1
        pulseTask?.cancel()
        pulseTask = nil
        isPlaying = false
        stopAudioSession()
    }

    func adjustTempo(by amount: Int) {
        bpm = min(DesignSystem.Tempo.maximumBPM, max(DesignSystem.Tempo.minimumBPM, bpm + amount))
    }

    func setTempo(_ newTempo: Int) {
        bpm = min(DesignSystem.Tempo.maximumBPM, max(DesignSystem.Tempo.minimumBPM, newTempo))
    }

    func setSoundEnabled(_ enabled: Bool) {
        guard isSoundEnabled != enabled else { return }
        isSoundEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: DesignSystem.Preferences.soundEnabledKey)
        guard isPlaying else { return }
        if enabled {
            activateAudioSession()
        } else {
            stopAudioSession()
        }
    }

    func setSoundVolume(_ volume: Double) {
        let clampedVolume = min(
            DesignSystem.Audio.maximumVolume,
            max(DesignSystem.Audio.minimumVolume, volume)
        )
        guard soundVolume != clampedVolume else { return }
        soundVolume = clampedVolume
        UserDefaults.standard.set(clampedVolume, forKey: DesignSystem.Preferences.soundVolumeKey)
        audioPlayer.setVolume(Float(clampedVolume))
    }

    func setHapticsEnabled(_ enabled: Bool) {
        guard isHapticsEnabled != enabled else { return }
        isHapticsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: DesignSystem.Preferences.hapticsEnabledKey)
    }

    func selectHapticIntensity(_ intensity: HapticIntensity) {
        guard isHapticsEnabled, !isPlaying else { return }
        if selectedHapticIntensity != intensity {
            selectedHapticIntensity = intensity
            UserDefaults.standard.set(intensity.rawValue, forKey: DesignSystem.Preferences.hapticIntensityKey)
        }
        testHaptics()
    }

    func testHaptics() {
        guard isHapticsEnabled, !isPlaying else { return }
        hapticPreviewTask?.cancel()
        let clock = ContinuousClock()
        hapticPreviewTask = Task(priority: .userInitiated) { [weak self] in
            do {
                try await clock.sleep(for: DesignSystem.Timing.hapticInteractionSeparation)
            } catch {
                return
            }
            guard let self, self.isHapticsEnabled, !self.isPlaying else { return }
            self.playSelectedHaptic()
            self.hapticPreviewTask = nil
        }
    }

    private func playSelectedHaptic() {
        WKInterfaceDevice.current().play(selectedHapticIntensity.watchKitType)
        hapticPulseCount += DesignSystem.Haptics.pulseIncrement
    }

    func tapTempo() {
        let now = Date()
        let interval = now.timeIntervalSince(lastTap)
        if interval > DesignSystem.Tempo.tapTempoMinimumInterval,
           interval < DesignSystem.Tempo.tapTempoMaximumInterval {
            setTempo(Int((DesignSystem.Timing.secondsPerMinute / interval).rounded()))
        }
        lastTap = now
    }

    private func pulse() {
        guard isPlaying else { return }
        elapsedSeconds = Int(Date().timeIntervalSince(phaseStart))

        if mode == .ramp {
            let rampSteps = elapsedSeconds / DesignSystem.Practice.rampIntervalSeconds
            bpm = min(
                DesignSystem.Tempo.maximumBPM,
                baseBPM + rampSteps * DesignSystem.Practice.rampIncreaseBPM
            )
        }

        let shouldClick: Bool
        if mode == .silence {
            let phase = elapsedSeconds / DesignSystem.Practice.silencePhaseSeconds
            shouldClick = phase.isMultiple(of: DesignSystem.Practice.silencePhasesPerCycle)
        } else {
            shouldClick = true
        }

        if shouldClick {
            if isHapticsEnabled {
                playSelectedHaptic()
            }
            if isSoundEnabled, audioSessionIsReady {
                audioPlayer.play(from: DesignSystem.Audio.playbackStartTime)
            }
        }
        beat = (beat + DesignSystem.Tempo.bpmAdjustmentStep) % beatsPerBar
    }

    private func playBeat(for generation: Int) -> Duration? {
        guard isPlaying, pulseGeneration == generation else { return nil }
        pulse()
        let intervalNanoseconds = Int64(
            (DesignSystem.Timing.nanosecondsPerMinute / Double(bpm)).rounded()
        )
        return .nanoseconds(intervalNanoseconds)
    }

    private func finishPulseTask(generation: Int) {
        guard pulseGeneration == generation else { return }
        pulseTask = nil
    }

    private func activateAudioSession(onReady: (() -> Void)? = nil) {
        audioSessionGeneration += 1
        let generation = audioSessionGeneration
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        } catch {
            audioSessionIsReady = false
            onReady?()
            return
        }
        session.activate(options: []) { [weak self] activated, _ in
            Task { @MainActor in
                guard let self else { return }
                guard self.audioSessionGeneration == generation else {
                    if activated, (!self.isPlaying || !self.isSoundEnabled) {
                        self.stopAudioSession()
                    }
                    return
                }
                let shouldContinue = self.isPlaying && self.isSoundEnabled
                self.audioSessionIsReady = activated && shouldContinue
                if shouldContinue {
                    onReady?()
                } else if activated {
                    self.stopAudioSession()
                }
            }
        }
    }

    private func stopAudioSession() {
        audioSessionGeneration += 1
        let generation = audioSessionGeneration
        audioSessionIsReady = false
        audioPlayer.stop { [weak self] in
            Task { @MainActor [weak self] in
                guard let self,
                      self.audioSessionGeneration == generation,
                      !self.isPlaying || !self.isSoundEnabled else { return }
                let session = AVAudioSession.sharedInstance()
                if #available(watchOS 27.0, *) {
                    session.deactivate(options: []) { _, _ in }
                } else {
                    DispatchQueue.global(qos: .utility).async {
                        try? session.setActive(false)
                    }
                }
            }
        }
    }
}

private final class AudioClickPlayer: @unchecked Sendable {
    private let playbackQueue = DispatchQueue(label: DesignSystem.Audio.playbackQueueLabel)
    private let audioURL = Bundle.main.url(
        forResource: DesignSystem.Assets.metronomeClick,
        withExtension: DesignSystem.Assets.waveFileExtension
    )
    private var player: AVAudioPlayer?

    init() {
        playbackQueue.async { [weak self] in
            guard let self, let audioURL = self.audioURL else { return }
            self.player = try? AVAudioPlayer(contentsOf: audioURL)
            self.player?.prepareToPlay()
        }
    }

    func play(from time: TimeInterval) {
        playbackQueue.async { [weak self] in
            guard let player = self?.player else { return }
            player.currentTime = time
            player.play()
        }
    }

    func setVolume(_ volume: Float) {
        playbackQueue.async { [weak self] in
            self?.player?.volume = volume
        }
    }

    func stop(completion: @escaping @Sendable () -> Void) {
        playbackQueue.async { [weak self] in
            self?.player?.stop()
            DispatchQueue.main.async(execute: completion)
        }
    }
}

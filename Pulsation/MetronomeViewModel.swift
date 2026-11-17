import AVFoundation
import Combine
import WatchKit

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
    @Published private(set) var isHapticsEnabled = DesignSystem.Preferences.defaultEnabled

    private var timer: Timer?
    private var lastTick = Date.distantPast
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
        if let savedHapticsPreference = UserDefaults.standard.object(forKey: DesignSystem.Preferences.hapticsEnabledKey) as? Bool {
            isHapticsEnabled = savedHapticsPreference
        }
    }

    func start() {
        guard !isPlaying else { return }
        baseBPM = bpm
        elapsedSeconds = DesignSystem.Tempo.initialElapsedSeconds
        beat = DesignSystem.Tempo.firstBeatIndex
        phaseStart = Date()
        lastTick = .distantPast

        isPlaying = true
        if isSoundEnabled {
            activateAudioSession { [weak self] in self?.beginPulseTimer() }
        } else {
            beginPulseTimer()
        }
    }

    private func beginPulseTimer() {
        guard isPlaying, timer == nil else { return }
        phaseStart = Date()
        lastTick = .distantPast
        let pulseTimer = Timer(timeInterval: DesignSystem.Timing.viewModelTickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pulse() }
        }
        timer = pulseTimer
        RunLoop.main.add(pulseTimer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
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

    func setHapticsEnabled(_ enabled: Bool) {
        guard isHapticsEnabled != enabled else { return }
        isHapticsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: DesignSystem.Preferences.hapticsEnabledKey)
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

        let beatInterval = 60.0 / Double(bpm)
        guard Date().timeIntervalSince(lastTick) >= beatInterval else { return }
        lastTick = Date()

        let shouldClick: Bool
        if mode == .silence {
            let phase = elapsedSeconds / DesignSystem.Practice.silencePhaseSeconds
            shouldClick = phase.isMultiple(of: DesignSystem.Practice.silencePhasesPerCycle)
        } else {
            shouldClick = true
        }

        if shouldClick {
            if isHapticsEnabled {
                WKInterfaceDevice.current().play(.click)
                hapticPulseCount += DesignSystem.Tempo.bpmAdjustmentStep
            }
            if isSoundEnabled, audioSessionIsReady {
                audioPlayer.play(from: DesignSystem.Audio.playbackStartTime)
            }
        }
        beat = (beat + DesignSystem.Tempo.bpmAdjustmentStep) % beatsPerBar
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
        }
    }

    func play(from time: TimeInterval) {
        playbackQueue.async { [weak self] in
            guard let player = self?.player else { return }
            player.currentTime = time
            player.play()
        }
    }

    func stop(completion: @escaping @Sendable () -> Void) {
        playbackQueue.async { [weak self] in
            self?.player?.stop()
            DispatchQueue.main.async(execute: completion)
        }
    }
}

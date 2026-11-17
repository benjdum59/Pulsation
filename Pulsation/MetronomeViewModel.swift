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
    private var audioPlayer: AVAudioPlayer?

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
        if let url = Bundle.main.url(
            forResource: DesignSystem.Assets.metronomeClick,
            withExtension: DesignSystem.Assets.waveFileExtension
        ) {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
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
        updateAudioSession()
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
        updateAudioSession()
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
        if isPlaying { updateAudioSession() }
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
            if isSoundEnabled {
                audioPlayer?.currentTime = DesignSystem.Audio.playbackStartTime
                audioPlayer?.play()
            }
        }
        beat = (beat + DesignSystem.Tempo.bpmAdjustmentStep) % beatsPerBar
    }

    private func updateAudioSession() {
        guard isPlaying, isSoundEnabled else {
            audioPlayer?.stop()
            try? AVAudioSession.sharedInstance().setActive(false)
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }
    }
}

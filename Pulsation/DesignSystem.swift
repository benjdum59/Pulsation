import SwiftUI

enum DesignSystem {
    enum Tempo {
        static let minimumBPM = 30
        static let maximumBPM = 240
        static let initialBPM = 96
        static let initialBeatsPerBar = 4
        static let initialElapsedSeconds = 0
        static let bpmAdjustmentStep = 1
        static let firstBeatIndex = 0
        static let tapTempoMinimumInterval: TimeInterval = 0.25
        static let tapTempoMaximumInterval: TimeInterval = 2.0
    }

    enum Practice {
        static let rampIncreaseBPM = 4
        static let rampIntervalSeconds = 60
        static let silencePhaseSeconds = 12
        static let silencePhasesPerCycle = 2
    }

    enum Timing {
        static let secondsPerMinute = 60.0
        static let nanosecondsPerMinute = 60_000_000_000.0
        static let hapticInteractionSeparation = Duration.milliseconds(200)
        static let pulseSleepTolerance = Duration.milliseconds(2)
    }

    enum Audio {
        static let playbackStartTime: TimeInterval = 0
        static let playbackQueueLabel = "com.bdt.pulsation.audio-playback"
        static let defaultVolume = 1.0
        static let minimumVolume = 0.0
        static let maximumVolume = 1.0
        static let volumeStep = 0.05
    }

    enum Haptics {
        static let initialPulseCount = 0
        static let pulseIncrement = 1
        static let firstArcIndex = 1
        static let lowArcCount = 1
        static let mediumArcCount = 2
        static let highArcCount = 3
        static let defaultIntensity: HapticIntensity = .medium
    }

    enum Preferences {
        static let soundEnabledKey = "metronome.settings.soundEnabled"
        static let soundVolumeKey = "metronome.settings.soundVolume"
        static let hapticsEnabledKey = "metronome.settings.hapticsEnabled"
        static let hapticIntensityKey = "metronome.settings.hapticIntensity"
        static let defaultEnabled = true
    }

    enum Layout {
        static let statusDot: CGFloat = 6
        static let smallStatusSpacing: CGFloat = 5
        static let statusFont: CGFloat = 10
        static let statusTracking: CGFloat = 1.4
        static let bpmFont: CGFloat = 56
        static let bpmUnitFont: CGFloat = 12
        static let bpmUnitSpacing: CGFloat = 4
        static let beatDotSpacing: CGFloat = 7
        static let beatDotSize: CGFloat = 7
        static let downbeatDotSize: CGFloat = 9
        static let beatDotsHeight: CGFloat = 14
        static let mainControlsSpacing: CGFloat = 16
        static let smallControlWidth: CGFloat = 34
        static let smallControlHeight: CGFloat = 30
        static let mainControlWidth: CGFloat = 52
        static let mainControlHeight: CGFloat = 40
        static let smallControlFont: CGFloat = 13
        static let mainControlFont: CGFloat = 15
        static let hintFont: CGFloat = 8
        static let hintTracking: CGFloat = 1.1
        static let tempoHorizontalPadding: CGFloat = 7
        static let tempoVerticalSpacing: CGFloat = 7
        static let trainingVerticalSpacing: CGFloat = 8
        static let modeTitleFont: CGFloat = 23
        static let subtitleFont: CGFloat = 11
        static let subtitleHeight: CGFloat = 28
        static let modeButtonSpacing: CGFloat = 5
        static let modeButtonFont: CGFloat = 8
        static let modeButtonVerticalPadding: CGFloat = 7
        static let startButtonFont: CGFloat = 12
        static let startButtonVerticalPadding: CGFloat = 2
        static let trainingHorizontalPadding: CGFloat = 8
        static let settingsVerticalSpacing: CGFloat = 8
        static let settingsControlSpacing: CGFloat = 4
        static let settingsRowSpacing: CGFloat = 8
        static let settingsRowFont: CGFloat = 13
        static let settingsVolumeFont: CGFloat = 11
        static let settingsTestButtonFont: CGFloat = 10
        static let settingsIntensityChoiceFont: CGFloat = 9
        static let settingsIntensityChoicesSpacing: CGFloat = 4
        static let settingsIntensityIconLabelSpacing: CGFloat = 2
        static let settingsIntensityChoiceMinimumHeight: CGFloat = 50
        static let settingsIconWidth: CGFloat = 22
        static let settingsHorizontalPadding: CGFloat = 10
        static let settingsHintFont: CGFloat = 8
        static let settingsHintLineLimit = 3
        static let hapticIconSize: CGFloat = 28
        static let hapticIconDotDiameter: CGFloat = 4
        static let hapticIconStrokeWidth: CGFloat = 1.5
        static let hapticIconFirstArcRadius: CGFloat = 6
        static let hapticIconArcRadiusStep: CGFloat = 4.5
        static let hapticArcHorizontalRatio: CGFloat = 0.75
        static let hapticArcEndpointHeightRatio: CGFloat = 0.35
        static let shapeCenterDivisor: CGFloat = 2
    }

    enum Opacity {
        static let idleDot: CGFloat = 0.5
        static let primaryBeat: CGFloat = 0.55
        static let regularBeat: CGFloat = 0.22
        static let secondaryControl: CGFloat = 0.14
    }

    enum Motion {
        static let beatScale: CGFloat = 1.2
        static let idleScale: CGFloat = 1
        static let beatAnimationDuration: TimeInterval = 0.16
    }

    enum Palette {
        static let accent = Color.mint
        static let idle = Color.gray.opacity(Opacity.idleDot)
        static let inactiveBeat = Color.white.opacity(Opacity.regularBeat)
        static let inactiveDownbeat = Color.white.opacity(Opacity.primaryBeat)
        static let secondaryControl = Color.white.opacity(Opacity.secondaryControl)
    }

    enum Typography {
        static let rounded = Font.Design.rounded
    }

    enum Icons {
        static let decreaseTempo = "minus"
        static let increaseTempo = "plus"
        static let play = "play.fill"
        static let pause = "pause.fill"
        static let training = "waveform.path"
        static let sound = "speaker.wave.2.fill"
        static let haptics = "waveform"
    }

    enum Assets {
        static let metronomeClick = "click"
        static let waveFileExtension = "wav"
    }
}

enum L10n {
    static let statusPlaying = String(localized: "metronome.status.playing")
    static let statusMetronome = String(localized: "metronome.status.ready")
    static let tempoTapHint = String(localized: "metronome.tapTempoHint")
    static let tempoUnit = String(localized: "metronome.bpmUnit")
    static let trainingTitle = String(localized: "training.title")
    static let modeFree = String(localized: "mode.free")
    static let modeRamp = String(localized: "mode.ramp")
    static let modeSilence = String(localized: "mode.silence")
    static let modeFreeDescription = String(localized: "mode.free.description")
    static let modeRampDescription = String(localized: "mode.ramp.description")
    static let modeSilenceDescription = String(localized: "mode.silence.description")
    static let rampBadge = String(localized: "mode.ramp.badge")
    static let silenceBadge = String(localized: "mode.silence.badge")
    static let actionStart = String(localized: "action.start")
    static let actionPause = String(localized: "action.pause")
    static let settingsTitle = String(localized: "settings.title")
    static let settingsSound = String(localized: "settings.sound")
    static let settingsSoundLevel = String(localized: "settings.soundLevel")
    static let settingsHaptics = String(localized: "settings.haptics")
    static let settingsTestHaptics = String(localized: "settings.hapticsTest")
    static let settingsHapticIntensity = String(localized: "settings.hapticIntensity")
    static let settingsHapticsIntensityHint = String(localized: "settings.hapticsIntensityHint")
    static let hapticIntensityLow = String(localized: "haptics.intensity.low")
    static let hapticIntensityMedium = String(localized: "haptics.intensity.medium")
    static let hapticIntensityHigh = String(localized: "haptics.intensity.high")
}

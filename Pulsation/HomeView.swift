import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: MetronomeViewModel
    @State private var crownTempo = Double(DesignSystem.Tempo.initialBPM)

    var body: some View {
        TabView {
            tempoView
            trainingView
            settingsView
        }
        .tabViewStyle(.verticalPage)
        .onChange(of: viewModel.bpm) { _, value in crownTempo = Double(value) }
    }

    private var tempoView: some View {
        VStack(spacing: DesignSystem.Layout.tempoVerticalSpacing) {
            HStack(spacing: DesignSystem.Layout.smallStatusSpacing) {
                Circle()
                    .fill(viewModel.isPlaying ? DesignSystem.Palette.accent : DesignSystem.Palette.idle)
                    .frame(width: DesignSystem.Layout.statusDot, height: DesignSystem.Layout.statusDot)
                Text(viewModel.isPlaying ? L10n.statusPlaying : L10n.statusMetronome)
                    .font(.system(size: DesignSystem.Layout.statusFont, weight: .bold, design: DesignSystem.Typography.rounded))
                    .tracking(DesignSystem.Layout.statusTracking)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Layout.bpmUnitSpacing) {
                Text("\(viewModel.bpm)")
                    .font(.system(size: DesignSystem.Layout.bpmFont, weight: .semibold, design: DesignSystem.Typography.rounded))
                    .monospacedDigit()
                Text(L10n.tempoUnit)
                    .font(.system(size: DesignSystem.Layout.bpmUnitFont, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: DesignSystem.Layout.beatDotSpacing) {
                ForEach(DesignSystem.Tempo.firstBeatIndex..<viewModel.beatsPerBar, id: \.self) { index in
                    let isActiveBeat = viewModel.isPlaying && index == viewModel.beat
                    let isDownbeat = index == DesignSystem.Tempo.firstBeatIndex
                    Circle()
                        .fill(beatColor(isDownbeat: isDownbeat, isActive: isActiveBeat))
                        .frame(width: isDownbeat ? DesignSystem.Layout.downbeatDotSize : DesignSystem.Layout.beatDotSize,
                               height: isDownbeat ? DesignSystem.Layout.downbeatDotSize : DesignSystem.Layout.beatDotSize)
                        .scaleEffect(isActiveBeat ? DesignSystem.Motion.beatScale : DesignSystem.Motion.idleScale)
                        .animation(.spring(duration: DesignSystem.Motion.beatAnimationDuration), value: viewModel.beat)
                }
            }
            .frame(height: DesignSystem.Layout.beatDotsHeight)

            HStack(spacing: DesignSystem.Layout.mainControlsSpacing) {
                Button { viewModel.adjustTempo(by: -DesignSystem.Tempo.bpmAdjustmentStep) } label: {
                    Image(systemName: DesignSystem.Icons.decreaseTempo)
                        .font(.system(size: DesignSystem.Layout.smallControlFont, weight: .bold))
                        .frame(width: DesignSystem.Layout.smallControlWidth, height: DesignSystem.Layout.smallControlHeight)
                }
                .tint(DesignSystem.Palette.secondaryControl)

                Button { viewModel.isPlaying ? viewModel.stop() : viewModel.start() } label: {
                    Image(systemName: viewModel.isPlaying ? DesignSystem.Icons.pause : DesignSystem.Icons.play)
                        .font(.system(size: DesignSystem.Layout.mainControlFont, weight: .bold))
                        .frame(width: DesignSystem.Layout.mainControlWidth, height: DesignSystem.Layout.mainControlHeight)
                }
                .tint(DesignSystem.Palette.accent)

                Button { viewModel.adjustTempo(by: DesignSystem.Tempo.bpmAdjustmentStep) } label: {
                    Image(systemName: DesignSystem.Icons.increaseTempo)
                        .font(.system(size: DesignSystem.Layout.smallControlFont, weight: .bold))
                        .frame(width: DesignSystem.Layout.smallControlWidth, height: DesignSystem.Layout.smallControlHeight)
                }
                .tint(DesignSystem.Palette.secondaryControl)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)

            Text(L10n.tempoTapHint)
                .font(.system(size: DesignSystem.Layout.hintFont, weight: .semibold))
                .tracking(DesignSystem.Layout.hintTracking)
                .foregroundStyle(.tertiary)
                .onTapGesture { viewModel.tapTempo() }
        }
        .padding(.horizontal, DesignSystem.Layout.tempoHorizontalPadding)
        .focusable()
        .digitalCrownRotation(
            $crownTempo,
            from: Double(DesignSystem.Tempo.minimumBPM),
            through: Double(DesignSystem.Tempo.maximumBPM),
            by: Double(DesignSystem.Tempo.bpmAdjustmentStep),
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: viewModel.isHapticsEnabled
        )
        .onChange(of: crownTempo) { _, value in viewModel.setTempo(Int(value.rounded())) }
    }

    private var trainingView: some View {
        VStack(spacing: DesignSystem.Layout.trainingVerticalSpacing) {
            HStack(spacing: DesignSystem.Layout.smallStatusSpacing) {
                Image(systemName: DesignSystem.Icons.training)
                    .foregroundStyle(DesignSystem.Palette.accent)
                Text(L10n.trainingTitle)
                    .font(.system(size: DesignSystem.Layout.statusFont, weight: .bold))
                    .tracking(DesignSystem.Layout.statusTracking)
            }

            Text(viewModel.mode.title)
                .font(.system(size: DesignSystem.Layout.modeTitleFont, weight: .semibold, design: DesignSystem.Typography.rounded))

            Text(viewModel.mode.subtitle)
                .font(.system(size: DesignSystem.Layout.subtitleFont))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(height: DesignSystem.Layout.subtitleHeight)

            HStack(spacing: DesignSystem.Layout.modeButtonSpacing) {
                ForEach(MetronomeViewModel.PracticeMode.allCases) { mode in
                    Button { viewModel.mode = mode } label: {
                        Text(mode.badge ?? mode.title)
                            .font(.system(size: DesignSystem.Layout.modeButtonFont, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Layout.modeButtonVerticalPadding)
                    }
                    .tint(viewModel.mode == mode ? DesignSystem.Palette.accent : DesignSystem.Palette.secondaryControl)
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)

            Button { viewModel.isPlaying ? viewModel.stop() : viewModel.start() } label: {
                Label(
                    viewModel.isPlaying ? L10n.actionPause : L10n.actionStart,
                    systemImage: viewModel.isPlaying ? DesignSystem.Icons.pause : DesignSystem.Icons.play
                )
                .font(.system(size: DesignSystem.Layout.startButtonFont, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Layout.startButtonVerticalPadding)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Palette.accent)
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, DesignSystem.Layout.trainingHorizontalPadding)
    }

    private var settingsView: some View {
        VStack(spacing: DesignSystem.Layout.settingsVerticalSpacing) {
            Text(L10n.settingsTitle)
                .font(.system(size: DesignSystem.Layout.modeTitleFont, weight: .semibold, design: DesignSystem.Typography.rounded))

            Toggle(isOn: Binding(
                get: { viewModel.isSoundEnabled },
                set: { viewModel.setSoundEnabled($0) }
            )) {
                HStack(spacing: DesignSystem.Layout.settingsRowSpacing) {
                    Image(systemName: DesignSystem.Icons.sound)
                        .frame(width: DesignSystem.Layout.settingsIconWidth)
                    Text(L10n.settingsSound)
                        .font(.system(size: DesignSystem.Layout.settingsRowFont, weight: .medium))
                }
            }
            .tint(DesignSystem.Palette.accent)

            Toggle(isOn: Binding(
                get: { viewModel.isHapticsEnabled },
                set: { viewModel.setHapticsEnabled($0) }
            )) {
                HStack(spacing: DesignSystem.Layout.settingsRowSpacing) {
                    Image(systemName: DesignSystem.Icons.haptics)
                        .frame(width: DesignSystem.Layout.settingsIconWidth)
                        .symbolEffect(.pulse, options: .nonRepeating, value: viewModel.hapticPulseCount)
                    Text(L10n.settingsHaptics)
                        .font(.system(size: DesignSystem.Layout.settingsRowFont, weight: .medium))
                }
            }
            .tint(DesignSystem.Palette.accent)

            Text(L10n.settingsHapticsPreview)
                .font(.system(size: DesignSystem.Layout.settingsHintFont))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DesignSystem.Layout.settingsHorizontalPadding)
    }

    private func beatColor(isDownbeat: Bool, isActive: Bool) -> Color {
        if isActive { return DesignSystem.Palette.accent }
        return isDownbeat ? DesignSystem.Palette.inactiveDownbeat : DesignSystem.Palette.inactiveBeat
    }
}

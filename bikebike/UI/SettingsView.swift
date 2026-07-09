//
//  SettingsView.swift
//  bikebike
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @AppStorage(AudioPreferences.musicEnabledKey) private var musicEnabled = true
    @AppStorage(AudioPreferences.sfxEnabledKey) private var sfxEnabled = true
    @AppStorage(AudioPreferences.hapticsEnabledKey) private var hapticsEnabled = true

    var body: some View {
        ZStack {
            BikeBikeBackground()

            VStack {
                HStack {
                    BikeBikeBackButton {
                        dismiss()
                    }
                    Spacer()
                }
                .padding(.leading, 24)
                .padding(.top, 16)

                Spacer()

                BikeBikeModalCard {
                    HeadingBanner(title: "Settings")
                } content: {
                    VStack(spacing: 16) {
                        SettingsToggleRow(
                            title: "Music",
                            systemImage: "speaker.wave.2.fill",
                            isOn: $musicEnabled
                        )
                        SettingsToggleRow(
                            title: "Sound Effects",
                            systemImage: "waveform",
                            isOn: $sfxEnabled
                        )
                        SettingsToggleRow(
                            title: "Haptics",
                            systemImage: "iphone.radiowaves.left.and.right",
                            isOn: $hapticsEnabled
                        )
                    }
                    .padding(.bottom, 8)
                }
                .frame(width: 380)
                .padding(.trailing, 72)

                Spacer()
            }
        }
        .onChange(of: musicEnabled) { _, enabled in
            AudioPreferences.isMusicEnabled = enabled
            if enabled {
                if appState.phase.playsBackgroundMusic {
                    AudioManager.shared.startBackgroundMusic()
                }
            } else {
                AudioManager.shared.stopBackgroundMusic(fade: true)
            }
        }
        .onChange(of: sfxEnabled) { _, enabled in
            AudioPreferences.isSFXEnabled = enabled
            if !enabled {
                AudioManager.shared.stopRaceAudio()
            }
        }
        .onChange(of: hapticsEnabled) { _, enabled in
            AudioPreferences.isHapticsEnabled = enabled
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(BikeBikeTheme.skyBlue)
                .frame(width: 28)

            Text(title)
                .font(BikeBikeTheme.bodyFont(size: 18))
                .foregroundStyle(BikeBikeTheme.darkBlue)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(BikeBikeTheme.skyBlue)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }
}

#Preview("Settings", traits: .landscapeLeft) {
    SettingsView()
        .environment(PreviewData.appState())
}

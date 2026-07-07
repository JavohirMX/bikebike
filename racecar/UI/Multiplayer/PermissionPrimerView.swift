//
//  PermissionPrimerView.swift
//  racecar
//

import SwiftUI

struct PermissionPrimerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Back") { appState.backFromPermissionPrimer() }
                    .font(.subheadline)
                Spacer()
                Text("Before you connect")
                    .font(.headline)
                Spacer()
                Color.clear.frame(width: 44)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            GeometryReader { geometry in
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        primerRow(
                            icon: "wifi",
                            title: "Same Wi‑Fi",
                            body: "Both phones on the same network. Hotspot works too."
                        )
                        primerRow(
                            icon: "hand.raised.fill",
                            title: "Tap Allow next",
                            body: "iOS will ask for local network access. Tap Allow."
                        )
                        primerRow(
                            icon: "gearshape",
                            title: "Settings note",
                            body: "AR Racecar appears in Settings only after you tap Continue."
                        )
                    }
                    .frame(width: geometry.size.width * 0.55, alignment: .leading)
                    .padding(.trailing, 16)

                    Divider()

                    VStack(spacing: 16) {
                        Image(systemName: "network")
                            .font(.largeTitle)
                            .foregroundStyle(Color.accentColor)
                        Text("Ready to connect?")
                            .font(.subheadline.bold())
                        Text("Tap Continue, then Allow on the iOS dialog.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button {
                            appState.continueFromPermissionPrimer()
                        } label: {
                            Text("Continue")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(width: geometry.size.width * 0.45 - 1)
                    .padding(.leading, 16)
                }
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func primerRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                Text(body)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

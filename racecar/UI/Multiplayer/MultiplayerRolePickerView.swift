//
//  MultiplayerRolePickerView.swift
//  racecar
//

import SwiftUI

struct MultiplayerRolePickerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Back") { appState.goHome() }
                    .font(.subheadline)
                Spacer()
                Text("Play Together")
                    .font(.headline)
                Spacer()
                Color.clear.frame(width: 44)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            GeometryReader { geometry in
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Who are you?")
                            .font(.subheadline.bold())
                        Text("Pick a role to connect with a friend on the same Wi‑Fi.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: geometry.size.width * 0.38, alignment: .leading)
                    .padding(.trailing, 16)

                    Divider()

                    VStack(spacing: 12) {
                        roleCard(
                            title: "I'm hosting",
                            subtitle: "Set up the race on this phone",
                            systemImage: "flag.checkered",
                            action: { appState.selectMultiplayerRole(.host) }
                        )
                        roleCard(
                            title: "I'm joining",
                            subtitle: "Connect to a friend's race",
                            systemImage: "qrcode.viewfinder",
                            action: { appState.selectMultiplayerRole(.guest) }
                        )
                    }
                    .frame(width: geometry.size.width * 0.62 - 1)
                    .padding(.leading, 16)
                }
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func roleCard(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

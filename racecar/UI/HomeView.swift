//
//  HomeView.swift
//  racecar
//

import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 20) {
                Text("AR RACECAR")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("Feasibility MVP")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(spacing: 14) {
                    primaryButton("Practice") { appState.startSoloPractice() }
                    primaryButton("Play Together") { appState.beginPlayTogether() }
                }
                .frame(maxWidth: 360)
                Text("Play Together walks you through hosting or joining with a QR code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

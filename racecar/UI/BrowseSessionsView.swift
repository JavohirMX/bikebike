//
//  BrowseSessionsView.swift
//  racecar
//

import SwiftUI

struct BrowseSessionsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("Nearby Races")

            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Searching for nearby races…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 8)

            if appState.discoveredSessions.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Text("No races nearby")
                        .font(.headline)
                    Text("Ask a friend to tap Host Race first, then stay in the Host Lobby on the same Wi‑Fi or Personal Hotspot.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Connection Help") {
                        appState.showConnectionHelp = true
                    }
                    .font(.subheadline)
                }
                Spacer()
            } else {
                List(appState.discoveredSessions) { session in
                    Button {
                        appState.joinSession(session)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.hostName)
                                .font(.headline)
                            Text("\(session.lapCount) laps · \(session.playerCount)/\(session.maxPlayers) players")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: Binding(
            get: { appState.showConnectionHelp },
            set: { appState.showConnectionHelp = $0 }
        )) {
            MultiplayerConnectionHelpView()
        }
        .onDisappear {
            appState.cancelBrowseHelpTimerOnLeave()
        }
    }

    private func header(_ title: String) -> some View {
        HStack {
            Button("Back") { appState.goHome() }
            Spacer()
            Text(title).font(.headline)
            Spacer()
            Button("Refresh") { appState.refreshBrowsing() }
                .font(.subheadline)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

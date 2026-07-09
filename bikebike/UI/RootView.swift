//
//  RootView.swift
//  bikebike
//

import SwiftUI

struct RootView: View {
    @State private var appState = AppState()

    var body: some View {
        ZStack {
            if showsAR {
                ARRaceView()
            }

            switch appState.phase {
            case .home:
                HomeView()
            case .soloDriverSelect:
                SoloDriverSelectView()
            case .soloLapSelect:
                SoloLapSelectView()
            case .multiplayerRolePicker:
                MultiplayerRolePickerView()
            case .multiplayerNickname:
                MultiplayerNicknameView()
            case .multiplayerHostDriverSelect:
                MultiplayerHostDriverSelectView()
            case .permissionPrimer:
                PermissionPrimerView()
            case .multiplayerLapSelect:
                MultiplayerLapSelectView()
            case .hostSetup:
                HostSetupView()
            case .guestSetup:
                GuestSetupView()
            case .browseSessions:
                BrowseSessionsView()
            case .hostLobby:
                HostLobbyView()
            case .guestLobby:
                GuestLobbyView()
            case .placement, .countdown, .racing:
                EmptyView()
            case .results:
                ResultsView()
            }

            if let departure = appState.homeDeparture {
                HomeDepartureOverlay(style: departure)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .environment(appState)
        .onOpenURL { url in
            appState.handleJoinURL(url)
        }
        .onAppear {
            AudioManager.shared.syncBackgroundMusic(for: appState.phase)
        }
        .onChange(of: appState.phase) { _, phase in
            AudioManager.shared.syncBackgroundMusic(for: phase)
        }
        .onReceive(NotificationCenter.default.publisher(for: .audioPreferencesChanged)) { _ in
            AudioManager.shared.syncBackgroundMusic(for: appState.phase)
            if !AudioPreferences.isSFXEnabled {
                AudioManager.shared.stopRaceAudio()
            }
        }
    }

    private var showsAR: Bool {
        switch appState.phase {
        case .placement, .countdown, .racing, .guestLobby:
            return true
        case .guestSetup:
            return appState.isSessionConnected || appState.isRelocalizing
        case .hostLobby, .hostSetup:
            return appState.trackPlaced
        default:
            return false
        }
    }
}

#Preview("Root", traits: .landscapeLeft) {
    RootView()
}

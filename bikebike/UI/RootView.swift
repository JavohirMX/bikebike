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
            case .soloLapSelect:
                SoloLapSelectView()
            case .multiplayerRolePicker:
                MultiplayerRolePickerView()
            case .permissionPrimer:
                PermissionPrimerView()
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
            case .placement, .racing:
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
    }

    private var showsAR: Bool {
        switch appState.phase {
        case .placement, .racing, .guestLobby:
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

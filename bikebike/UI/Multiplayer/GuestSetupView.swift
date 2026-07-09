//
//  GuestSetupView.swift
//  bikebike
//

import SwiftUI

struct GuestSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var showBrowseFallback = false

    var body: some View {
        Group {
            if appState.lobbyReady && appState.trackPlaced && appState.phase != .racing {
                GuestWaitingView()
            } else {
                scannerContent
            }
        }
    }

    private var scannerContent: some View {
        ZStack {
            // Background Scanner
            QRCodeScannerView { payload in
                if appState.targetHostName == nil && !appState.isSessionConnected {
                    appState.handleScannedJoinLink(payload)
                }
            }
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Viewfinder and text overlay
            if appState.targetHostName == nil && !appState.isSessionConnected && !appState.isRelocalizing && !appState.isLoadingTrackAssets {
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color(hex: "3A8FD4") ?? .blue, lineWidth: 4)
                        .frame(width: 280, height: 280)
                    
                    Text("Scan the QR Code to Join")
                        .font(BikeBikeTheme.bodyFont(size: 20))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
            }
            
            // Connecting, loading track assets, or relocalizing
            if appState.isLoadingTrackAssets {
                statusOverlay(
                    title: "Loading track...",
                    message: "Preparing the race track from the host."
                )
            } else if appState.isRelocalizing {
                statusOverlay(
                    title: "Aligning to table...",
                    message: "Point your phone at the same table as the host."
                )
            } else if appState.isSessionConnected {
                connectedLobbyOverlay
            } else if let host = appState.targetHostName {
                statusOverlay(
                    title: "Connecting...",
                    message: "Finding \(host) on the network..."
                )
            }
            
            // Errors
            VStack {
                if let error = appState.sessionErrorMessage {
                    SessionErrorBanner(message: error) {
                        appState.retrySession()
                    }
                    .padding()
                } else if let lobbyError = appState.lobbySyncErrorMessage {
                    SessionErrorBanner(message: lobbyError) {
                        appState.retrySession()
                    }
                    .padding()
                } else if let joinError = appState.qrJoinErrorMessage {
                    Text(joinError)
                        .font(BikeBikeTheme.bodyFont(size: 14))
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .clipShape(Capsule())
                        .padding()
                }
                Spacer()
            }
        }
        .overlay(alignment: .topLeading) {
            BikeBikeBackButton { 
                appState.backFromGuestSetup() 
            }
            .padding(.leading, 32)
            .padding(.top, 24)
            .ignoresSafeArea()
        }
    }
    
    private var connectedLobbyOverlay: some View {
        VStack(spacing: 20) {
            Text("Connected")
                .font(BikeBikeTheme.titleFont(size: 24))
                .foregroundStyle(.white)

            Text(appState.trackPlaced ? "Track placed — pick your driver" : "Joined lobby — pick your driver")
                .font(BikeBikeTheme.bodyFont(size: 16))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            DriverSelectGrid(
                selectedDriverId: appState.localSelectedDriverId,
                takenDriverIds: appState.takenDriverIds,
                takenByName: appState.takenDriverNames,
                compact: true
            ) { driverId in
                appState.selectDriver(driverId)
            }
            .padding(.horizontal, 24)

            if let error = appState.driverSelectionError {
                Text(error)
                    .font(BikeBikeTheme.captionFont(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.75))
                    .clipShape(Capsule())
            }
        }
        .padding(28)
        .frame(maxWidth: 420)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 10)
    }

    private func statusOverlay(title: String, message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text(title)
                .font(BikeBikeTheme.titleFont(size: 24))
                .foregroundStyle(.white)
            Text(message)
                .font(BikeBikeTheme.bodyFont(size: 16))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 10)
    }
}

#Preview("Scanning") {
    GuestSetupView()
        .environment(PreviewData.appState {
            $0.phase = .guestSetup
            $0.role = .guest
        })
}

#Preview("Loading Track") {
    GuestSetupView()
        .environment(PreviewData.appState {
            $0.phase = .guestSetup
            $0.role = .guest
            $0.isSessionConnected = true
            $0.isLoadingTrackAssets = true
            $0.connectedHostName = "Talin's iPhone"
        })
}

#Preview("Connected") {
    GuestSetupView()
        .environment(PreviewData.appState {
            $0.phase = .guestSetup
            $0.role = .guest
            $0.isSessionConnected = true
            $0.connectedHostName = "Talin's iPhone"
            $0.players = PreviewData.players
        })
}

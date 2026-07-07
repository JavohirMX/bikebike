//
//  GuestWaitingView.swift
//  bikebike
//

import SwiftUI

struct GuestWaitingView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            BikeBikeBackground(blurRadius: 6)

            VStack(spacing: 32) {
                HStack {
                    BikeBikeBackButton { appState.goHome() }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer()

                Text("Waiting for host to start...")
                    .font(BikeBikeTheme.bodyFont(size: 22))
                    .foregroundStyle(BikeBikeTheme.darkBlue)

                LoadingTrackView()
                    .padding(.horizontal, 48)

                Spacer()
            }
        }
    }
}

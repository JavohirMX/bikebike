//
//  MultiplayerRolePickerView.swift
//  bikebike
//

import SwiftUI

struct MultiplayerRolePickerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            BikeBikeBackground(blurRadius: 2)

            VStack {
                HStack {
                    BikeBikeBackButton { appState.goHome() }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer()

                VStack(spacing: 20) {
                    MultiplayerBanner()

                    VStack(spacing: 14) {
                        BikeBikePillButton(title: "Create Game", style: .yellow) {
                            appState.selectMultiplayerRole(.host)
                        }

                        BikeBikePillButton(title: "Join Game", style: .blue) {
                            appState.selectMultiplayerRole(.guest)
                        }
                    }
                    .frame(width: 280)
                }
                .padding(.trailing, 48)
                .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer()
            }
        }
    }
}

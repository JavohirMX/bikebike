//
//  MultiplayerConnectionHelpView.swift
//  bikebike
//

import SwiftUI

struct MultiplayerConnectionHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Can't connect?")
                        .font(.title2.bold())

                    helpSection(
                        title: "Host goes first",
                        body: "Device A: Play Together → I'm hosting → Continue → Allow. Stay on the Host Setup screen and show your QR code."
                    )

                    helpSection(
                        title: "Guest scans the QR code",
                        body: "Device B: Play Together → I'm joining → Continue → Allow → scan the host's QR code. Or tap Can't scan? Pick from list."
                    )

                    helpSection(
                        title: "Same Wi‑Fi",
                        body: "Both phones must be on the same Wi‑Fi. Personal Hotspot on the host phone is the most reliable option."
                    )

                    helpSection(
                        title: "Local Network permission",
                        body: "Tap Allow when iOS asks. BikeBike only appears in Settings → Privacy → Local Network after you tap Continue — that's normal. If you denied access, reinstall the app or enable BikeBike in Settings."
                    )

                    helpSection(
                        title: "Still stuck?",
                        body: "Tap Try Again on the setup screen. Use two real iPhones (not Simulator). Turn off VPN. Make sure the host placed the track after the guest connected, then taps Start Race."
                    )
                }
                .padding()
            }
            .navigationTitle("Connection Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func helpSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

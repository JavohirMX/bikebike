//
//  LoadingTrackView.swift
//  bikebike
//

import SwiftUI

struct LoadingTrackView: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        Image("loading-track")
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { geometry in
                    let trackWidth = geometry.size.width
                    let trackHeight = geometry.size.height
                        
                    // Inset the start and end so the bike stays within the yellow border
                    let startX = trackWidth * 0.08
                    let endX = trackWidth * 0.8
                    let bikeX = startX + (endX - startX) * progress
                    
                    let bikeHeight = trackHeight * 0.45
                    let tailWidth = trackWidth * 0.15
                    
                    // Glowing tail (speed blur)
                    LinearGradient(
                        colors: [.white, .white.opacity(0.0)],
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                    .frame(width: tailWidth, height: trackHeight * 0.1)
                    .clipShape(Capsule())
                    .position(x: bikeX - (tailWidth * 0.5) - (bikeHeight * 0.2), y: trackHeight * 0.5)
                    .shadow(color: .white.opacity(0.8), radius: 4, x: 0, y: 0)
                    .opacity(progress > 0.05 && progress < 0.95 ? 1 : 0) // fade out near edges

                    // The Bike
                    Image("rider-ish")
                        .resizable()
                        .scaledToFit()
                        .frame(height: bikeHeight)
                        .position(x: bikeX, y: trackHeight * 0.28) 
                }
            }
            .frame(maxWidth: 500) // Restored road size
            .onAppear {
                progress = 0
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    progress = 1
                }
            }
    }
}

#Preview("Loading Track") {
    GuestWaitingView()
        .environment(PreviewData.appState {
            $0.phase = .guestSetup
            $0.role = .guest
            $0.players = PreviewData.players
            $0.trackPlaced = true
        })
}

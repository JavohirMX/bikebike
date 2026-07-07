//
//  LoadingTrackView.swift
//  racecar
//

import SwiftUI

struct LoadingTrackView: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("loading-track")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)

                Image("rider-ish")
                    .resizable()
                    .scaledToFit()
                    .frame(height: geometry.size.height * 0.55)
                    .offset(x: (progress - 0.5) * geometry.size.width * 0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 80)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                progress = 1
            }
        }
    }
}

//
//  TrackSelectGrid.swift
//  bikebike
//

import SwiftUI

struct TrackSelectGrid: View {
    let selectedTrackId: String
    var compact: Bool = false
    let onSelect: (String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: compact ? 10 : 14) {
            ForEach(RaceTrackCatalog.allOptions) { option in
                TrackSelectCard(
                    option: option,
                    isSelected: option.id == selectedTrackId,
                    compact: compact
                ) {
                    onSelect(option.id)
                }
            }
        }
    }
}

private struct TrackSelectCard: View {
    let option: TrackOption
    let isSelected: Bool
    var compact: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: compact ? 4 : 6) {
                TrackThumbnailImage(option: option)
                    .frame(height: compact ? 52 : 64)

                Text(option.shortTitle)
                    .font(BikeBikeTheme.captionFont(size: compact ? 11 : 13))
                    .foregroundStyle(BikeBikeTheme.darkBlue)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 6 : 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(BikeBikeTheme.skyBlue, lineWidth: isSelected ? 3 : 0)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

struct TrackThumbnailImage: View {
    let option: TrackOption

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(option.thumbnailAssetName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(
                colors: [Color.black.opacity(0.18), .clear],
                startPoint: .top,
                endPoint: .center
            )

            if option.isPrimary {
                Text("Featured")
                    .font(BikeBikeTheme.captionFont(size: 9))
                    .foregroundStyle(BikeBikeTheme.darkBlue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(BikeBikeTheme.cream.opacity(0.95))
                    .clipShape(Capsule())
                    .padding(4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
    }
}

#Preview("Track Select Grid") {
    TrackSelectGrid(selectedTrackId: RaceTrackCatalog.defaultTrackId, compact: true) { _ in }
        .padding()
        .background(BikeBikeBackground())
}

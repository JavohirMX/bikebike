//
//  DriverSelectGrid.swift
//  bikebike
//

import SwiftUI

struct DriverSelectGrid: View {
    let selectedDriverId: String
    let takenDriverIds: Set<String>
    let takenByName: [String: String]
    var compact: Bool = false
    let onSelect: (String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: compact ? 10 : 14) {
            ForEach(DriverCatalog.all) { driver in
                DriverSelectCard(
                    driver: driver,
                    isSelected: driver.id == selectedDriverId,
                    isTaken: takenDriverIds.contains(driver.id) && driver.id != selectedDriverId,
                    takenBy: takenByName[driver.id],
                    compact: compact
                ) {
                    onSelect(driver.id)
                }
            }
        }
    }
}

private struct DriverSelectCard: View {
    let driver: Driver
    let isSelected: Bool
    let isTaken: Bool
    let takenBy: String?
    var compact: Bool
    let onTap: () -> Void

    private var accentColor: Color {
        Color(hex: driver.accentColorHex) ?? .accentColor
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: compact ? 4 : 6) {
                Image(DriverCatalog.resolvedImageName(for: driver))
                    .resizable()
                    .scaledToFit()
                    .frame(width: compact ? 40 : 56, height: compact ? 40 : 56)
                    .opacity(isTaken ? 0.35 : 1)

                Text(driver.displayName)
                    .font(BikeBikeTheme.captionFont(size: compact ? 12 : 14))
                    .foregroundStyle(BikeBikeTheme.darkBlue)
                    .lineLimit(1)

                if let takenBy {
                    Text(takenBy)
                        .font(BikeBikeTheme.captionFont(size: 10))
                        .foregroundStyle(BikeBikeTheme.darkBlue.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 6 : 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isTaken ? 0.45 : 0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(accentColor, lineWidth: isSelected ? 3 : 0)
            )
        }
        .buttonStyle(.plain)
        .disabled(isTaken)
    }
}

#Preview("Driver Select Grid") {
    DriverSelectGrid(
        selectedDriverId: "talin",
        takenDriverIds: ["ish", "ana"],
        takenByName: ["ish": "Ish", "ana": "Ana"]
    ) { _ in }
    .padding()
    .background(BikeBikeBackground())
}

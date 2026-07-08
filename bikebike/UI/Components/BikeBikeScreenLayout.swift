//
//  BikeBikeScreenLayout.swift
//  bikebike
//

import SwiftUI

private struct BikeBikeScreenContentModifier: ViewModifier {
    let maxWidth: CGFloat
    let horizontalPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
    }
}

extension View {
    func bikeBikeScreenContent(maxWidth: CGFloat = 640, horizontalPadding: CGFloat = 24) -> some View {
        modifier(BikeBikeScreenContentModifier(maxWidth: maxWidth, horizontalPadding: horizontalPadding))
    }
}

struct AdaptiveColumnLayout<Left: View, Right: View>: View {
    var leftRatio: CGFloat = 0.5
    var columnSpacing: CGFloat = 0
    var showsDivider: Bool = false
    var scrollLeftWhenWide: Bool = false
    @ViewBuilder let left: () -> Left
    @ViewBuilder let right: () -> Right

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wideLayout
            narrowLayout
        }
    }

    private var wideLayout: some View {
        GeometryReader { geometry in
            let dividerWidth: CGFloat = showsDivider ? 1 : 0
            let availableWidth = geometry.size.width - columnSpacing - dividerWidth
            let leftWidth = availableWidth * leftRatio
            let rightWidth = availableWidth * (1 - leftRatio)

            HStack(alignment: .top, spacing: columnSpacing) {
                Group {
                    if scrollLeftWhenWide {
                        ScrollView {
                            left()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        left()
                    }
                }
                .frame(width: leftWidth)

                if showsDivider {
                    Divider()
                        .padding(.vertical, 4)
                }

                right()
                    .frame(width: rightWidth)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(minHeight: 200)
    }

    private var narrowLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: columnSpacing) {
                left()
                right()
            }
        }
    }
}

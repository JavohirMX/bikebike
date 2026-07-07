//
//  MultiplayerSetupShell.swift
//  bikebike
//

import SwiftUI

struct MultiplayerSetupShell<Left: View, Right: View, Banner: View>: View {
    let title: String
    let onLeave: () -> Void
    let onHelp: (() -> Void)?
    @ViewBuilder let banner: () -> Banner
    @ViewBuilder let leftColumn: () -> Left
    @ViewBuilder let rightColumn: () -> Right

    init(
        title: String,
        onLeave: @escaping () -> Void,
        onHelp: (() -> Void)? = nil,
        @ViewBuilder banner: @escaping () -> Banner = { EmptyView() },
        @ViewBuilder leftColumn: @escaping () -> Left,
        @ViewBuilder rightColumn: @escaping () -> Right
    ) {
        self.title = title
        self.onLeave = onLeave
        self.onHelp = onHelp
        self.banner = banner
        self.leftColumn = leftColumn
        self.rightColumn = rightColumn
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            banner()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            GeometryReader { geometry in
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        leftColumn()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(width: geometry.size.width * 0.42)

                    Divider()
                        .padding(.vertical, 4)

                    rightColumn()
                        .frame(width: geometry.size.width * 0.58 - 1)
                        .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var topBar: some View {
        HStack {
            Button("Leave", action: onLeave)
                .font(.subheadline)
            Spacer()
            Text(title)
                .font(.headline)
            Spacer()
            if let onHelp {
                Button("Help", action: onHelp)
                    .font(.subheadline)
            } else {
                Color.clear.frame(width: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

extension MultiplayerSetupShell where Banner == EmptyView {
    init(
        title: String,
        onLeave: @escaping () -> Void,
        onHelp: (() -> Void)? = nil,
        @ViewBuilder leftColumn: @escaping () -> Left,
        @ViewBuilder rightColumn: @escaping () -> Right
    ) {
        self.init(
            title: title,
            onLeave: onLeave,
            onHelp: onHelp,
            banner: { EmptyView() },
            leftColumn: leftColumn,
            rightColumn: rightColumn
        )
    }
}

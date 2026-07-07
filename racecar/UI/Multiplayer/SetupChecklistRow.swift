//
//  SetupChecklistRow.swift
//  racecar
//

import SwiftUI

enum SetupStepStatus {
    case pending
    case active
    case done
}

struct SetupChecklistStep: Identifiable {
    let id: Int
    let title: String
    let subtitle: String?
    let status: SetupStepStatus
}

struct SetupChecklistView: View {
    let steps: [SetupChecklistStep]
    var compact: Bool = false
    var sectionTitle: String = "Progress"

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            Text(sectionTitle)
                .font(.subheadline.bold())
            ForEach(steps) { step in
                SetupChecklistRow(
                    number: step.id,
                    title: step.title,
                    subtitle: step.subtitle,
                    status: step.status,
                    compact: compact
                )
            }
        }
    }
}

struct SetupChecklistRow: View {
    let number: Int
    let title: String
    let subtitle: String?
    let status: SetupStepStatus
    var compact: Bool = false

    private var circleSize: CGFloat { compact ? 22 : 28 }

    var body: some View {
        HStack(alignment: .top, spacing: compact ? 8 : 12) {
            ZStack {
                Circle()
                    .fill(circleFill)
                    .frame(width: circleSize, height: circleSize)
                if status == .done {
                    Image(systemName: "checkmark")
                        .font(compact ? .caption2.bold() : .caption.bold())
                        .foregroundStyle(.white)
                } else if status == .active {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Text("\(number)")
                        .font(compact ? .caption2.bold() : .caption.bold())
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(compact ? .caption.bold() : .subheadline.bold())
                    .foregroundStyle(status == .pending ? .secondary : .primary)
                if let subtitle {
                    Text(subtitle)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, compact ? 2 : 4)
    }

    private var circleFill: Color {
        switch status {
        case .done: return .green
        case .active: return .accentColor
        case .pending: return Color(.systemGray5)
        }
    }
}

struct SessionErrorBanner: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Local network access blocked", systemImage: "wifi.exclamationmark")
                .font(.subheadline.bold())
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

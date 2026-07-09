//
//  BikeBikeNicknameField.swift
//  bikebike
//

import SwiftUI

struct BikeBikeNicknameField: View {
    @Binding var text: String
    var placeholder: String = "Nickname"
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder).foregroundStyle(Color(white: 0.35))
        )
        .font(BikeBikeTheme.bodyFont(size: 20))
        .foregroundStyle(.black)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .submitLabel(.done)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .stroke(.white, lineWidth: 2)
        )
        .onSubmit {
            onSubmit?()
        }
    }
}

enum NicknameValidator {
    static let maxLength = 16

    static func isValid(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (1...maxLength).contains(trimmed.count)
    }
}

#Preview("Nickname Field") {
    @Previewable @State var nickname = ""
    BikeBikeNicknameField(text: $nickname)
        .padding()
        .background(BikeBikeTheme.darkBlue)
}

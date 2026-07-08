//
//  QRCodeView.swift
//  bikebike
//

import CoreImage.CIFilterBuiltins
import SwiftUI

struct QRCodeView: View {
    let urlString: String
    var size: CGFloat = 200

    var body: some View {
        if let image = generateQRCode(from: urlString) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(width: size, height: size)
                .overlay {
                    Text("QR unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview("QR Code") {
    QRCodeView(urlString: "bikebike://join?host=Talin", size: 180)
        .padding()
}

import AppIntents
import Foundation
import OSLog
import UIKit
import UniformTypeIdentifiers

struct QuickLookTinyPNGIntent: AppIntent {
    static var title: LocalizedStringResource = "Debug Tiny PNG"
    static var description = IntentDescription(
        "Returns a tiny generated PNG file for isolating Shortcuts Quick Look output handling."
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let pngData = Self.renderTinyPNG()
        let logger = Logger(
            subsystem: "AlenShamatov.ScreenTranslator",
            category: "QuickLookIntent"
        )
        let outputFile = IntentFile(
            data: pngData,
            filename: "tiny.png",
            type: .png
        )

        logger.info(
            "QL_TINY_RETURN_START bytes=\(pngData.count, privacy: .public) mode=data"
        )

        return .result(value: outputFile)
    }

    private static func renderTinyPNG() -> Data {
        let size = CGSize(width: 400, height: 400)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.pngData { _ in
            let rect = CGRect(origin: .zero, size: size)
            UIColor(
                red: 0.95,
                green: 0.97,
                blue: 1.0,
                alpha: 1
            ).setFill()
            UIRectFill(rect)

            let text = "Tiny PNG OK"
            let font = UIFont.systemFont(ofSize: 36, weight: .bold)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]
            let textRect = CGRect(
                x: 20,
                y: 172,
                width: 360,
                height: 60
            )

            NSString(string: text).draw(
                with: textRect,
                options: [
                    .usesLineFragmentOrigin,
                    .usesFontLeading
                ],
                attributes: attributes,
                context: nil
            )
        }
    }
}

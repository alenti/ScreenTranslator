import CoreGraphics
import Foundation
import UIKit

struct OverlayTextFitter {
    struct FittedText: Equatable, Sendable {
        let text: String
        let fontSize: Double
        let lineLimit: Int?
        let measuredSize: CGSize
        let lineCount: Int
    }

    func fit(
        text: String,
        within availableSize: CGSize,
        style: OverlayRenderStyle
    ) -> FittedText {
        let normalizedText = normalized(text)
        let constrainedWidth = max(availableSize.width, 1)
        let constrainedHeight = max(availableSize.height, 1)

        var selectedMeasurement: TextMeasurement?

        for fontSize in stride(
            from: style.maximumFontSize,
            through: style.minimumFontSize,
            by: -1
        ) {
            let measurement = measure(
                text: normalizedText,
                fontSize: fontSize,
                constrainedWidth: constrainedWidth,
                style: style
            )
            selectedMeasurement = measurement

            if measurement.size.height <= constrainedHeight {
                break
            }
        }

        let resolvedMeasurement = selectedMeasurement
            ?? measure(
                text: normalizedText,
                fontSize: style.minimumFontSize,
                constrainedWidth: constrainedWidth,
                style: style
            )

        return FittedText(
            text: normalizedText,
            fontSize: resolvedMeasurement.fontSize,
            lineLimit: nil,
            measuredSize: resolvedMeasurement.size,
            lineCount: resolvedMeasurement.lineCount
        )
    }

    private func normalized(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { line in
                line.trimmingCharacters(in: .whitespaces)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func measure(
        text: String,
        fontSize: Double,
        constrainedWidth: CGFloat,
        style: OverlayRenderStyle
    ) -> TextMeasurement {
        let font = UIFont.systemFont(
            ofSize: CGFloat(fontSize),
            weight: .semibold
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = style.lineSpacingValue

        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        )

        let measuredRect = attributedString.boundingRect(
            with: CGSize(
                width: constrainedWidth,
                height: .greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let measuredLineHeight = font.lineHeight + style.lineSpacingValue
        let lineCount = max(
            1,
            Int(
                ceil(
                    max(measuredRect.height, font.lineHeight) / max(measuredLineHeight, 1)
                )
            )
        )

        return TextMeasurement(
            fontSize: fontSize,
            size: CGSize(
                width: max(ceil(measuredRect.width), 1),
                height: max(ceil(measuredRect.height), ceil(font.lineHeight))
            ),
            lineCount: lineCount
        )
    }
}

private struct TextMeasurement {
    let fontSize: Double
    let size: CGSize
    let lineCount: Int
}

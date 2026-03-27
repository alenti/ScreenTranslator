import CoreGraphics
import Foundation
import UIKit

struct OverlayImageComposer {
    struct RenderInstruction: Equatable, Sendable {
        let blockID: UUID
        let outerFrame: CGRect
        let textFrame: CGRect
        let text: String
        let fontSize: Double
        let style: OverlayRenderStyle
    }

    func composeImageData(
        for input: ScreenshotInput,
        instructions: [RenderInstruction]
    ) throws -> Data? {
        guard let baseImage = UIImage(data: input.imageData) else {
            throw AppError.unsupportedImage
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(
            size: input.size,
            format: format
        )

        return renderer.pngData { context in
            let canvasRect = CGRect(origin: .zero, size: input.size)
            baseImage.draw(in: canvasRect)

            for instruction in instructions {
                draw(
                    instruction: instruction,
                    in: context.cgContext
                )
            }
        }
    }

    private func draw(
        instruction: RenderInstruction,
        in context: CGContext
    ) {
        let palette = palette(for: instruction.style)
        let blockPath = UIBezierPath(
            roundedRect: instruction.outerFrame,
            cornerRadius: instruction.style.cornerRadiusValue
        )

        context.saveGState()
        context.setFillColor(palette.background.cgColor)
        blockPath.fill()
        context.restoreGState()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = instruction.style.lineSpacingValue

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(
                ofSize: CGFloat(instruction.fontSize),
                weight: .semibold
            ),
            .foregroundColor: palette.text,
            .paragraphStyle: paragraphStyle
        ]

        NSString(string: instruction.text).draw(
            with: instruction.textFrame,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
    }

    private func palette(
        for style: OverlayRenderStyle
    ) -> (background: UIColor, text: UIColor) {
        let backgroundOpacity = min(
            max(style.backgroundOpacityValue, 0),
            1
        )

        return (
            background: UIColor.black.withAlphaComponent(backgroundOpacity),
            text: UIColor(white: 1, alpha: 0.98)
        )
    }
}

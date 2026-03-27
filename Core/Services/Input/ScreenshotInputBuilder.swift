import CoreGraphics
import Foundation
import ImageIO

struct ScreenshotInputBuilder {
    struct ImageMetadata: Equatable, Sendable {
        let pixelSize: CGSize
        let orientation: ScreenshotInput.Orientation
    }

    func build(
        imageData: Data,
        sourceMetadata: ScreenshotInput.SourceMetadata = .scaffold,
        scale: CGFloat = 1.0,
        timestamp: Date = .now
    ) throws -> ScreenshotInput {
        let metadata = try imageMetadata(from: imageData)

        return build(
            imageData: imageData,
            size: metadata.pixelSize,
            orientation: metadata.orientation,
            scale: scale,
            timestamp: timestamp,
            sourceMetadata: sourceMetadata
        )
    }

    func build(
        imageData: Data,
        size: CGSize,
        orientation: ScreenshotInput.Orientation = .up,
        scale: CGFloat = 1.0,
        timestamp: Date = .now,
        sourceMetadata: ScreenshotInput.SourceMetadata = .scaffold
    ) -> ScreenshotInput {
        ScreenshotInput(
            imageData: imageData,
            size: sanitize(size: size),
            orientation: orientation,
            scale: sanitize(scale: scale),
            timestamp: timestamp,
            sourceMetadata: sourceMetadata
        )
    }

    func imageMetadata(from imageData: Data) throws -> ImageMetadata {
        guard imageData.isEmpty == false else {
            throw AppError.unsupportedImage
        }

        guard
            let source = CGImageSourceCreateWithData(imageData as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
            width.isFinite,
            height.isFinite,
            width > 0,
            height > 0
        else {
            throw AppError.unsupportedImage
        }

        let orientationValue = properties[kCGImagePropertyOrientation] as? UInt32

        return ImageMetadata(
            pixelSize: CGSize(width: width, height: height),
            orientation: orientation(from: orientationValue)
        )
    }

    private func orientation(from rawValue: UInt32?) -> ScreenshotInput.Orientation {
        switch rawValue {
        case 3:
            return .down
        case 6:
            return .right
        case 8:
            return .left
        default:
            return .up
        }
    }

    private func sanitize(size: CGSize) -> CGSize {
        CGSize(
            width: sanitize(dimension: size.width),
            height: sanitize(dimension: size.height)
        )
    }

    private func sanitize(scale: CGFloat) -> CGFloat {
        guard scale.isFinite, scale > 0 else {
            return 1.0
        }

        return scale
    }

    private func sanitize(dimension: CGFloat) -> CGFloat {
        guard dimension.isFinite else {
            return 1.0
        }

        let magnitude = abs(dimension)
        return magnitude > 0 ? magnitude : 1.0
    }
}

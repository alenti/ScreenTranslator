import CoreGraphics
import Foundation

struct ScreenshotNormalizer {
    private let orientationResolver: ImageOrientationResolver
    private let defaultScale: CGFloat

    init(
        orientationResolver: ImageOrientationResolver,
        defaultScale: CGFloat = 1.0
    ) {
        self.orientationResolver = orientationResolver
        self.defaultScale = defaultScale
    }

    func normalize(_ input: ScreenshotInput) -> ScreenshotInput {
        let sanitizedSize = sanitize(size: input.size)
        let resolvedOrientation = orientationResolver.resolve(
            size: sanitizedSize,
            orientation: input.orientation
        )

        return ScreenshotInput(
            id: input.id,
            imageData: input.imageData,
            size: resolvedOrientation.normalizedSize,
            orientation: resolvedOrientation.normalizedOrientation,
            scale: sanitize(scale: input.scale),
            timestamp: input.timestamp,
            sourceMetadata: input.sourceMetadata
        )
    }

    private func sanitize(size: CGSize) -> CGSize {
        CGSize(
            width: sanitize(dimension: size.width),
            height: sanitize(dimension: size.height)
        )
    }

    private func sanitize(scale: CGFloat) -> CGFloat {
        guard scale.isFinite, scale > 0 else {
            return defaultScale
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

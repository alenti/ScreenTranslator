import CoreGraphics
import Foundation

struct ImageOrientationResolver {
    struct Resolution: Equatable, Sendable {
        let normalizedSize: CGSize
        let normalizedOrientation: ScreenshotInput.Orientation
        let swapsCanvasDimensions: Bool
    }

    func resolve(for input: ScreenshotInput) -> Resolution {
        resolve(size: input.size, orientation: input.orientation)
    }

    func resolve(
        size: CGSize,
        orientation: ScreenshotInput.Orientation
    ) -> Resolution {
        let swapsCanvasDimensions = orientation == .left || orientation == .right
        let normalizedSize = swapsCanvasDimensions
            ? CGSize(width: size.height, height: size.width)
            : size

        return Resolution(
            normalizedSize: normalizedSize,
            normalizedOrientation: .up,
            swapsCanvasDimensions: swapsCanvasDimensions
        )
    }
}

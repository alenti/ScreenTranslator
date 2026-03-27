import CoreGraphics
import Foundation

struct OverlayRenderStyle: Equatable, Sendable, Codable {
    enum TextColorStyle: String, CaseIterable, Sendable, Codable {
        case automatic
        case light
        case dark
    }

    var minimumFontSize: Double
    var maximumFontSize: Double
    var padding: Double
    var backgroundOpacity: Double
    var cornerRadius: Double
    var textColorStyle: TextColorStyle

    var lineSpacing: Double {
        2
    }

    var maximumBlockWidthRatio: Double {
        0.86
    }

    var minimumBlockWidth: Double {
        120
    }

    var blockWidthExpansionMultiplier: Double {
        1.4
    }

    var horizontalCanvasInsetRatio: Double {
        0.03
    }

    var verticalCanvasInsetRatio: Double {
        0.02
    }

    var minimumFontSizeValue: CGFloat {
        CGFloat(minimumFontSize)
    }

    var maximumFontSizeValue: CGFloat {
        CGFloat(maximumFontSize)
    }

    var paddingValue: CGFloat {
        CGFloat(padding)
    }

    var backgroundOpacityValue: CGFloat {
        CGFloat(backgroundOpacity)
    }

    var cornerRadiusValue: CGFloat {
        CGFloat(cornerRadius)
    }

    var lineSpacingValue: CGFloat {
        CGFloat(lineSpacing)
    }

    var maximumBlockWidthRatioValue: CGFloat {
        CGFloat(maximumBlockWidthRatio)
    }

    var minimumBlockWidthValue: CGFloat {
        CGFloat(minimumBlockWidth)
    }

    var blockWidthExpansionMultiplierValue: CGFloat {
        CGFloat(blockWidthExpansionMultiplier)
    }

    var horizontalCanvasInsetRatioValue: CGFloat {
        CGFloat(horizontalCanvasInsetRatio)
    }

    var verticalCanvasInsetRatioValue: CGFloat {
        CGFloat(verticalCanvasInsetRatio)
    }

    static let defaultValue = OverlayRenderStyle(
        minimumFontSize: 12,
        maximumFontSize: 22,
        padding: 8,
        backgroundOpacity: 0.78,
        cornerRadius: 10,
        textColorStyle: .automatic
    )
}

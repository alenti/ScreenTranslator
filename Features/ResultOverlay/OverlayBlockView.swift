import SwiftUI

struct OverlayBlockView: View {
    enum PresentationStyle {
        case textList
        case floatingOverlay
        case positionedOverlay
    }

    let block: TranslationBlock
    let style: PresentationStyle

    init(
        block: TranslationBlock,
        style: PresentationStyle = .textList
    ) {
        self.block = block
        self.style = style
    }

    var body: some View {
        VStack(alignment: .leading, spacing: style == .textList ? 8 : 0) {
            Text(block.translatedText)
                .font(translatedFont)
                .foregroundStyle(primaryTextColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if style == .textList, block.sourceText.isEmpty == false {
                Text(block.sourceText)
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(block.renderingStyle.paddingValue)
        .background(backgroundView)
        .overlay(
            RoundedRectangle(cornerRadius: block.renderingStyle.cornerRadiusValue)
                .strokeBorder(borderColor)
        )
    }

    private var translatedFont: Font {
        switch style {
        case .textList:
            return .headline
        case .floatingOverlay:
            return .body.weight(.semibold)
        case .positionedOverlay:
            return .system(
                size: positionedOverlayFontSize,
                weight: .semibold
            )
        }
    }

    private var positionedOverlayFontSize: CGFloat {
        let availableHeight = max(
            block.targetFrame.height - (block.renderingStyle.paddingValue * 2),
            block.renderingStyle.minimumFontSizeValue
        )
        let lineCount = max(
            block.translatedText.components(separatedBy: "\n").count,
            1
        )
        let fittedFontSize = availableHeight / (CGFloat(lineCount) * 1.24)

        return min(
            block.renderingStyle.maximumFontSizeValue,
            max(
                block.renderingStyle.minimumFontSizeValue,
                fittedFontSize
            )
        )
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: block.renderingStyle.cornerRadiusValue)
            .fill(backgroundColor)
    }

    private var backgroundColor: Color {
        switch style {
        case .textList:
            return Color.white.opacity(0.08)
        case .floatingOverlay, .positionedOverlay:
            return Color.black.opacity(
                min(
                    max(block.renderingStyle.backgroundOpacityValue, 0),
                    1
                )
            )
        }
    }

    private var borderColor: Color {
        switch style {
        case .textList:
            return Color.white.opacity(0.08)
        case .floatingOverlay, .positionedOverlay:
            return Color.white.opacity(0.08)
        }
    }

    private var primaryTextColor: Color {
        switch style {
        case .textList:
            return .white
        case .floatingOverlay, .positionedOverlay:
            return .white
        }
    }

    private var secondaryTextColor: Color {
        switch style {
        case .textList:
            return .white.opacity(0.64)
        case .floatingOverlay, .positionedOverlay:
            return .white.opacity(0.72)
        }
    }
}

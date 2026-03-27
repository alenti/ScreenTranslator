import SwiftUI
import UIKit

struct OverlayCanvasView: View {
    @Environment(\.colorScheme) private var colorScheme

    let result: OverlayRenderResult
    let mode: ResultMode
    let chromeHidden: Bool
    let selectedBlockID: UUID?
    let resetToken: Int
    let onViewerTap: () -> Void
    let onBlockTap: (TranslationBlock) -> Void

    var body: some View {
        Group {
            switch mode {
            case .overlay:
                overlayViewer
            case .original:
                originalViewer
            case .text:
                transcriptFallbackView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(viewerBackgroundColor)
    }

    private var overlayViewer: some View {
        Group {
            if let renderedPreviewImage {
                viewer(
                    image: renderedPreviewImage,
                    hotspots: overlayHotspots
                )
            } else if let sourcePreviewImage {
                fallbackOverlayViewer(sourceImage: sourcePreviewImage)
            } else {
                unavailableViewer(
                    title: "Rendered preview unavailable",
                    subtitle: "The app does not have a translated screenshot to display yet."
                )
            }
        }
    }

    private var originalViewer: some View {
        Group {
            if let sourcePreviewImage {
                viewer(
                    image: sourcePreviewImage,
                    hotspots: originalHotspots
                )
            } else {
                unavailableViewer(
                    title: "Original screenshot unavailable",
                    subtitle: "The source screenshot is missing for this result."
                )
            }
        }
    }

    private var transcriptFallbackView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(result.translatedBlocks) { block in
                    OverlayBlockView(block: block)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
        .background(viewerBackgroundColor)
    }

    private func viewer(
        image: UIImage,
        hotspots: [ZoomablePreviewHotspot]
    ) -> some View {
        ZoomablePreviewImage(
            image: image,
            canvasSize: result.sourceInput.size,
            resetToken: resetToken,
            chromeHidden: chromeHidden,
            hotspots: hotspots,
            highlightedHotspotID: selectedBlockID,
            onSingleTap: onViewerTap,
            onHotspotTap: handleHotspotTap(_:)
        )
        .ignoresSafeArea()
    }

    private func fallbackOverlayViewer(sourceImage: UIImage) -> some View {
        GeometryReader { geometry in
            let transform = OverlayFallbackTransform(
                containerSize: geometry.size,
                sourceCanvasSize: result.sourceInput.size
            )

            ZStack(alignment: .topLeading) {
                viewerBackgroundColor

                Image(uiImage: sourceImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(
                        width: transform.canvasRect.width,
                        height: transform.canvasRect.height
                    )
                    .offset(
                        x: transform.canvasRect.minX,
                        y: transform.canvasRect.minY
                    )

                ForEach(result.translatedBlocks) { block in
                    let projectedFrame = transform.project(block.targetFrame)

                    if projectedFrame.isEmpty == false {
                        Button {
                            onBlockTap(block)
                        } label: {
                            OverlayBlockView(
                                block: block,
                                style: .positionedOverlay
                            )
                            .frame(
                                width: max(projectedFrame.width, 44),
                                height: max(projectedFrame.height, 24),
                                alignment: .topLeading
                            )
                        }
                        .buttonStyle(.plain)
                        .offset(
                            x: projectedFrame.minX,
                            y: projectedFrame.minY
                        )
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onViewerTap)
        }
        .ignoresSafeArea()
    }

    private func unavailableViewer(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(unavailableSecondaryTextColor)

            Text(title)
                .font(.headline)
                .foregroundStyle(unavailablePrimaryTextColor)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(unavailableSecondaryTextColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(viewerBackgroundColor)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onViewerTap)
    }

    private var renderedPreviewImage: UIImage? {
        guard let data = result.precomposedImageData else {
            return nil
        }

        return UIImage(data: data)
    }

    private var sourcePreviewImage: UIImage? {
        UIImage(data: result.sourceInput.imageData)
    }

    private var overlayHotspots: [ZoomablePreviewHotspot] {
        result.translatedBlocks.map { block in
            ZoomablePreviewHotspot(
                id: block.id,
                frame: block.targetFrame,
                accessibilityLabel: block.translatedText
            )
        }
    }

    private var originalHotspots: [ZoomablePreviewHotspot] {
        result.translatedBlocks.map { block in
            ZoomablePreviewHotspot(
                id: block.id,
                frame: block.sourceBoundingBox,
                accessibilityLabel: block.sourceText
            )
        }
    }

    private func handleHotspotTap(_ hotspot: ZoomablePreviewHotspot) {
        guard let block = result.translatedBlocks.first(where: { $0.id == hotspot.id }) else {
            return
        }

        onBlockTap(block)
    }

    private var viewerBackgroundColor: Color {
        colorScheme == .dark
            ? .black
            : Color(red: 0.95, green: 0.96, blue: 0.98)
    }

    private var unavailablePrimaryTextColor: Color {
        colorScheme == .dark
            ? .white
            : Color.primary
    }

    private var unavailableSecondaryTextColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.56)
            : Color.secondary
    }
}

private struct OverlayFallbackTransform {
    let canvasRect: CGRect
    let sourceCanvasSize: CGSize

    init(
        containerSize: CGSize,
        sourceCanvasSize: CGSize
    ) {
        let safeSourceSize = CGSize(
            width: max(sourceCanvasSize.width, 1),
            height: max(sourceCanvasSize.height, 1)
        )
        self.sourceCanvasSize = safeSourceSize
        self.canvasRect = Self.aspectFitRect(
            for: safeSourceSize,
            inside: CGRect(origin: .zero, size: containerSize)
        )
    }

    func project(_ frame: CGRect) -> CGRect {
        let standardizedFrame = frame.standardized
        guard standardizedFrame.isEmpty == false else {
            return .zero
        }

        let scaleX = canvasRect.width / sourceCanvasSize.width
        let scaleY = canvasRect.height / sourceCanvasSize.height

        return CGRect(
            x: canvasRect.minX + (standardizedFrame.minX * scaleX),
            y: canvasRect.minY + (standardizedFrame.minY * scaleY),
            width: standardizedFrame.width * scaleX,
            height: standardizedFrame.height * scaleY
        )
    }

    private static func aspectFitRect(
        for sourceSize: CGSize,
        inside bounds: CGRect
    ) -> CGRect {
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return bounds
        }

        let widthScale = bounds.width / sourceSize.width
        let heightScale = bounds.height / sourceSize.height
        let scale = min(widthScale, heightScale)

        let fittedSize = CGSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )

        return CGRect(
            x: (bounds.width - fittedSize.width) / 2,
            y: (bounds.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}

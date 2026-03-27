import SwiftUI
import UIKit

struct DebugOverlayInspectorView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedStage: DebugInspectionStage

    let stages: [DebugInspectionStage]
    let comparisonSummary: String?
    let statusMessage: String
    let backdropDescription: String
    let previewImageData: Data?
    let previewCanvasSize: CGSize
    let inspectionBoxes: [DebugInspectionBox]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Visual Inspector")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(primaryTextColor)

                Text(selectedStage.subtitle)
                    .font(.footnote)
                    .foregroundStyle(secondaryTextColor)
            }

            Picker("Debug Stage", selection: $selectedStage) {
                ForEach(stages) { stage in
                    Text(stage.title).tag(stage)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(primaryTextColor.opacity(0.88))

                HStack(spacing: 8) {
                    statusBadge(text: backdropDescription)
                    statusBadge(text: "\(inspectionBoxes.count) guides")
                }

                if let comparisonSummary {
                    Text(comparisonSummary)
                        .font(.caption)
                        .foregroundStyle(secondaryTextColor)
                }
            }

            previewSurface
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(cardStroke)
        )
    }

    private var previewSurface: some View {
        Group {
            if let previewImage {
                GeometryReader { geometry in
                    let transform = DebugPreviewTransform(
                        containerSize: geometry.size,
                        imageCanvasSize: previewCanvasSize
                    )

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.black.opacity(0.92))

                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 22))

                        ForEach(inspectionBoxes) { box in
                            let projectedFrame = transform.project(box.frame)

                            if projectedFrame.isEmpty == false {
                                DebugGuideFrameView(
                                    stage: selectedStage,
                                    projectedFrame: projectedFrame,
                                    badgeText: box.badgeText,
                                    title: box.title,
                                    subtitle: box.subtitle,
                                    detail: box.detail
                                )
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.56))

                    Text("Preview Unavailable")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Run the shortcut with a screenshot, then reopen Debug to inspect OCR, grouping, translation, and overlay guides.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.black.opacity(0.72))
                )
            }
        }
        .frame(height: 420)
    }

    private var previewImage: UIImage? {
        guard let previewImageData else {
            return nil
        }

        return UIImage(data: previewImageData)
    }

    private func statusBadge(text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(primaryTextColor.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(badgeFill)
            )
            .overlay(
                Capsule()
                    .strokeBorder(cardStroke)
            )
    }

    private var primaryTextColor: Color {
        colorScheme == .dark
            ? .white
            : Color.primary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.68)
            : Color.secondary
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.white.opacity(0.76)
    }

    private var cardStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }

    private var badgeFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.05)
    }
}

private struct DebugGuideFrameView: View {
    let stage: DebugInspectionStage
    let projectedFrame: CGRect
    let badgeText: String
    let title: String
    let subtitle: String
    let detail: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(stage.accentColor.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(stage.accentColor, lineWidth: 1.5)
                )
                .frame(
                    width: max(projectedFrame.width, 2),
                    height: max(projectedFrame.height, 2)
                )
                .offset(
                    x: projectedFrame.minX,
                    y: projectedFrame.minY
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(badgeText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)

                if projectedFrame.width >= 68 {
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }

                if projectedFrame.width >= 92 {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }

                if projectedFrame.width >= 120 {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(stage.accentColor.opacity(0.88))
            )
            .offset(
                x: projectedFrame.minX + 4,
                y: max(projectedFrame.minY + 4, 4)
            )
        }
    }
}

private struct DebugPreviewTransform {
    let imageRect: CGRect
    let imageCanvasSize: CGSize

    init(containerSize: CGSize, imageCanvasSize: CGSize) {
        let safeCanvasSize = CGSize(
            width: max(imageCanvasSize.width, 1),
            height: max(imageCanvasSize.height, 1)
        )
        self.imageCanvasSize = safeCanvasSize
        self.imageRect = Self.aspectFitRect(
            for: safeCanvasSize,
            inside: CGRect(origin: .zero, size: containerSize)
        )
    }

    func project(_ frame: CGRect) -> CGRect {
        let standardizedFrame = frame.standardized
        guard standardizedFrame.isEmpty == false else {
            return .zero
        }

        let scaleX = imageRect.width / imageCanvasSize.width
        let scaleY = imageRect.height / imageCanvasSize.height

        return CGRect(
            x: imageRect.minX + (standardizedFrame.minX * scaleX),
            y: imageRect.minY + (standardizedFrame.minY * scaleY),
            width: standardizedFrame.width * scaleX,
            height: standardizedFrame.height * scaleY
        )
    }

    private static func aspectFitRect(
        for imageSize: CGSize,
        inside bounds: CGRect
    ) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return bounds
        }

        let widthScale = bounds.width / imageSize.width
        let heightScale = bounds.height / imageSize.height
        let scale = min(widthScale, heightScale)

        let fittedSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        return CGRect(
            x: (bounds.width - fittedSize.width) / 2,
            y: (bounds.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}

private extension DebugInspectionStage {
    var accentColor: Color {
        switch self {
        case .ocrObservations:
            return Color.orange
        case .groupedBlocks:
            return Color.blue
        case .translatedBlocks:
            return Color.green
        case .overlayFrames:
            return Color.pink
        }
    }
}

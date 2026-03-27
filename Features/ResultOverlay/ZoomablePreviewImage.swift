import SwiftUI
import UIKit

struct ZoomablePreviewHotspot: Identifiable, Equatable, Sendable {
    let id: UUID
    let frame: CGRect
    let accessibilityLabel: String
}

struct ZoomablePreviewImage: View {
    @Environment(\.colorScheme) private var colorScheme

    let image: UIImage
    let canvasSize: CGSize
    let resetToken: Int
    let chromeHidden: Bool
    let hotspots: [ZoomablePreviewHotspot]
    let highlightedHotspotID: UUID?
    let onSingleTap: () -> Void
    let onHotspotTap: (ZoomablePreviewHotspot) -> Void

    var body: some View {
        ZoomableImageScrollView(
            image: image,
            canvasSize: canvasSize,
            resetToken: resetToken,
            interfaceStyle: colorScheme == .dark ? .dark : .light,
            chromeHidden: chromeHidden,
            hotspots: hotspots,
            highlightedHotspotID: highlightedHotspotID,
            onSingleTap: onSingleTap,
            onHotspotTap: onHotspotTap
        )
        .background(
            colorScheme == .dark
                ? Color.black
                : Color(red: 0.95, green: 0.96, blue: 0.98)
        )
    }
}

private struct ZoomableImageScrollView: UIViewRepresentable {
    let image: UIImage
    let canvasSize: CGSize
    let resetToken: Int
    let interfaceStyle: UIUserInterfaceStyle
    let chromeHidden: Bool
    let hotspots: [ZoomablePreviewHotspot]
    let highlightedHotspotID: UUID?
    let onSingleTap: () -> Void
    let onHotspotTap: (ZoomablePreviewHotspot) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.decelerationRate = .fast
        scrollView.backgroundColor = backgroundColor(for: interfaceStyle)
        scrollView.delaysContentTouches = false

        let contentView = UIView()
        contentView.backgroundColor = .clear

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleToFill
        imageView.isUserInteractionEnabled = false

        let hotspotContainer = UIView()
        hotspotContainer.backgroundColor = .clear
        hotspotContainer.isUserInteractionEnabled = true

        contentView.addSubview(imageView)
        contentView.addSubview(hotspotContainer)
        scrollView.addSubview(contentView)

        context.coordinator.attach(
            scrollView: scrollView,
            contentView: contentView,
            imageView: imageView,
            hotspotContainer: hotspotContainer
        )

        let singleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSingleTap(_:))
        )
        singleTap.delegate = context.coordinator
        singleTap.cancelsTouchesInView = false

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = context.coordinator

        singleTap.require(toFail: doubleTap)

        scrollView.addGestureRecognizer(singleTap)
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(
        _ scrollView: UIScrollView,
        context: Context
    ) {
        context.coordinator.update(
            image: image,
            canvasSize: canvasSize,
            in: scrollView,
            resetToken: resetToken,
            interfaceStyle: interfaceStyle,
            chromeHidden: chromeHidden,
            hotspots: hotspots,
            highlightedHotspotID: highlightedHotspotID,
            onSingleTap: onSingleTap,
            onHotspotTap: onHotspotTap
        )
    }

    private func backgroundColor(
        for interfaceStyle: UIUserInterfaceStyle
    ) -> UIColor {
        switch interfaceStyle {
        case .dark:
            return .black
        default:
            return UIColor(
                red: 0.95,
                green: 0.96,
                blue: 0.98,
                alpha: 1
            )
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        private weak var scrollView: UIScrollView?
        private weak var contentView: UIView?
        private weak var imageView: UIImageView?
        private weak var hotspotContainer: UIView?

        private var lastBoundsSize: CGSize = .zero
        private var lastCanvasSize: CGSize = .zero
        private var lastImageSize: CGSize = .zero
        private var lastResetToken = 0
        private var lastInterfaceStyle: UIUserInterfaceStyle = .unspecified
        private var lastChromeHidden = false
        private var lastHighlightedHotspotID: UUID?
        private var lastHotspots: [ZoomablePreviewHotspot] = []

        private var onSingleTap: (() -> Void)?
        private var onHotspotTap: ((ZoomablePreviewHotspot) -> Void)?

        func attach(
            scrollView: UIScrollView,
            contentView: UIView,
            imageView: UIImageView,
            hotspotContainer: UIView
        ) {
            self.scrollView = scrollView
            self.contentView = contentView
            self.imageView = imageView
            self.hotspotContainer = hotspotContainer
        }

        func update(
            image: UIImage,
            canvasSize: CGSize,
            in scrollView: UIScrollView,
            resetToken: Int,
            interfaceStyle: UIUserInterfaceStyle,
            chromeHidden: Bool,
            hotspots: [ZoomablePreviewHotspot],
            highlightedHotspotID: UUID?,
            onSingleTap: @escaping () -> Void,
            onHotspotTap: @escaping (ZoomablePreviewHotspot) -> Void
        ) {
            guard
                let contentView,
                let imageView,
                let hotspotContainer
            else {
                return
            }

            self.onSingleTap = onSingleTap
            self.onHotspotTap = onHotspotTap
            imageView.image = image
            scrollView.backgroundColor = backgroundColor(for: interfaceStyle)

            let safeCanvasSize = CGSize(
                width: max(canvasSize.width, 1),
                height: max(canvasSize.height, 1)
            )
            let boundsSize = scrollView.bounds.size

            guard boundsSize.width > 0, boundsSize.height > 0 else {
                DispatchQueue.main.async { [weak self, weak scrollView] in
                    guard let self, let scrollView else {
                        return
                    }

                    self.update(
                        image: image,
                        canvasSize: safeCanvasSize,
                        in: scrollView,
                        resetToken: resetToken,
                        interfaceStyle: interfaceStyle,
                        chromeHidden: chromeHidden,
                        hotspots: hotspots,
                        highlightedHotspotID: highlightedHotspotID,
                        onSingleTap: onSingleTap,
                        onHotspotTap: onHotspotTap
                    )
                }
                return
            }

            let boundsChanged = lastBoundsSize != boundsSize
            let canvasChanged = lastCanvasSize != safeCanvasSize
            let imageChanged = lastImageSize != image.size
            let shouldReset = resetToken != lastResetToken

            if boundsChanged || canvasChanged || imageChanged || shouldReset {
                configureBaseGeometry(
                    canvasSize: safeCanvasSize,
                    contentView: contentView,
                    imageView: imageView,
                    hotspotContainer: hotspotContainer,
                    in: scrollView
                )
                resetToFit(
                    in: scrollView,
                    animated: shouldReset
                )
                lastBoundsSize = boundsSize
                lastCanvasSize = safeCanvasSize
                lastImageSize = image.size
                lastResetToken = resetToken
            } else {
                updateViewport(
                    in: scrollView,
                    centerContent: false
                )
            }

            if lastHotspots != hotspots
                || lastInterfaceStyle != interfaceStyle
                || lastChromeHidden != chromeHidden
                || lastHighlightedHotspotID != highlightedHotspotID
                || boundsChanged
                || canvasChanged
            {
                rebuildHotspots(
                    hotspots,
                    canvasSize: safeCanvasSize,
                    in: hotspotContainer,
                    interfaceStyle: interfaceStyle,
                    chromeHidden: chromeHidden,
                    highlightedHotspotID: highlightedHotspotID
                )
                lastHotspots = hotspots
                lastInterfaceStyle = interfaceStyle
                lastChromeHidden = chromeHidden
                lastHighlightedHotspotID = highlightedHotspotID
            }
        }

        func viewForZooming(
            in scrollView: UIScrollView
        ) -> UIView? {
            contentView
        }

        func scrollViewDidZoom(
            _ scrollView: UIScrollView
        ) {
            updateViewport(
                in: scrollView,
                centerContent: false
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            (touch.view is UIControl) == false
        }

        @objc
        func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else {
                return
            }

            onSingleTap?()
        }

        @objc
        func handleDoubleTap(
            _ gesture: UITapGestureRecognizer
        ) {
            guard
                let scrollView,
                let contentView
            else {
                return
            }

            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                resetToFit(in: scrollView, animated: true)
                return
            }

            let targetScale = min(scrollView.maximumZoomScale, 2.5)
            let tapPoint = gesture.location(in: contentView)
            let zoomRect = zoomRect(
                for: scrollView,
                scale: targetScale,
                center: tapPoint
            )
            scrollView.zoom(to: zoomRect, animated: true)
        }

        @objc
        func handleHotspotButtonTap(_ sender: HotspotButton) {
            guard let hotspot = lastHotspots.first(where: { $0.id == sender.hotspotID }) else {
                return
            }

            onHotspotTap?(hotspot)
        }

        private func configureBaseGeometry(
            canvasSize: CGSize,
            contentView: UIView,
            imageView: UIImageView,
            hotspotContainer: UIView,
            in scrollView: UIScrollView
        ) {
            let fittedSize = aspectFitSize(
                for: canvasSize,
                inside: scrollView.bounds.size
            )

            contentView.frame = CGRect(
                origin: .zero,
                size: fittedSize
            )
            imageView.frame = contentView.bounds
            hotspotContainer.frame = contentView.bounds
            scrollView.contentSize = fittedSize
            scrollView.minimumZoomScale = 1
            scrollView.maximumZoomScale = 4
        }

        private func rebuildHotspots(
            _ hotspots: [ZoomablePreviewHotspot],
            canvasSize: CGSize,
            in hotspotContainer: UIView,
            interfaceStyle: UIUserInterfaceStyle,
            chromeHidden: Bool,
            highlightedHotspotID: UUID?
        ) {
            hotspotContainer.subviews.forEach { $0.removeFromSuperview() }

            let scaleX = hotspotContainer.bounds.width / max(canvasSize.width, 1)
            let scaleY = hotspotContainer.bounds.height / max(canvasSize.height, 1)

            for hotspot in hotspots {
                let frame = hotspot.frame.standardized
                guard frame.isEmpty == false else {
                    continue
                }

                let buttonFrame = CGRect(
                    x: frame.minX * scaleX,
                    y: frame.minY * scaleY,
                    width: frame.width * scaleX,
                    height: frame.height * scaleY
                )

                let button = HotspotButton(type: .custom)
                button.hotspotID = hotspot.id
                button.frame = buttonFrame
                button.accessibilityLabel = hotspot.accessibilityLabel
                button.accessibilityTraits = .button
                button.layer.cornerRadius = min(max(buttonFrame.height * 0.30, 10), 18)
                button.layer.borderWidth = highlightedHotspotID == hotspot.id
                    ? 1.5
                    : (chromeHidden ? 0 : 1)
                button.layer.borderColor = (
                    highlightedHotspotID == hotspot.id
                        ? accentColor(for: interfaceStyle).withAlphaComponent(0.84)
                        : accentColor(for: interfaceStyle).withAlphaComponent(
                            interfaceStyle == .dark ? 0.14 : 0.18
                        )
                ).cgColor
                button.backgroundColor = highlightedHotspotID == hotspot.id
                    ? accentColor(for: interfaceStyle).withAlphaComponent(
                        interfaceStyle == .dark ? 0.16 : 0.10
                    )
                    : accentColor(for: interfaceStyle).withAlphaComponent(
                        chromeHidden
                            ? 0.001
                            : (interfaceStyle == .dark ? 0.04 : 0.06)
                    )
                button.addTarget(
                    self,
                    action: #selector(handleHotspotButtonTap(_:)),
                    for: .touchUpInside
                )

                hotspotContainer.addSubview(button)
            }
        }

        private func resetToFit(
            in scrollView: UIScrollView,
            animated: Bool
        ) {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
            updateViewport(
                in: scrollView,
                centerContent: true
            )

            if animated {
                UIView.animate(withDuration: 0.22) {
                    scrollView.layoutIfNeeded()
                }
            }
        }

        private func updateViewport(
            in scrollView: UIScrollView,
            centerContent: Bool
        ) {
            let insets = centeredInsets(for: scrollView)
            scrollView.contentInset = insets

            let minimumOffset = CGPoint(
                x: -insets.left,
                y: -insets.top
            )

            if centerContent {
                scrollView.contentOffset = minimumOffset
                return
            }

            scrollView.contentOffset = clampedOffset(
                scrollView.contentOffset,
                in: scrollView,
                insets: insets
            )
        }

        private func centeredInsets(
            for scrollView: UIScrollView
        ) -> UIEdgeInsets {
            let horizontalInset = max(
                0,
                (scrollView.bounds.width - scrollView.contentSize.width) / 2
            )
            let verticalInset = max(
                0,
                (scrollView.bounds.height - scrollView.contentSize.height) / 2
            )

            return UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }

        private func clampedOffset(
            _ offset: CGPoint,
            in scrollView: UIScrollView,
            insets: UIEdgeInsets
        ) -> CGPoint {
            let minimumX = -insets.left
            let maximumX = max(
                scrollView.contentSize.width - scrollView.bounds.width + insets.right,
                minimumX
            )
            let minimumY = -insets.top
            let maximumY = max(
                scrollView.contentSize.height - scrollView.bounds.height + insets.bottom,
                minimumY
            )

            return CGPoint(
                x: min(max(offset.x, minimumX), maximumX),
                y: min(max(offset.y, minimumY), maximumY)
            )
        }

        private func zoomRect(
            for scrollView: UIScrollView,
            scale: CGFloat,
            center: CGPoint
        ) -> CGRect {
            let width = scrollView.bounds.size.width / scale
            let height = scrollView.bounds.size.height / scale

            return CGRect(
                x: center.x - (width / 2),
                y: center.y - (height / 2),
                width: width,
                height: height
            )
        }

        private func aspectFitSize(
            for canvasSize: CGSize,
            inside boundsSize: CGSize
        ) -> CGSize {
            guard canvasSize.width > 0, canvasSize.height > 0 else {
                return boundsSize
            }

            let widthScale = boundsSize.width / canvasSize.width
            let heightScale = boundsSize.height / canvasSize.height
            let scale = min(widthScale, heightScale)

            return CGSize(
                width: canvasSize.width * scale,
                height: canvasSize.height * scale
            )
        }

        private func backgroundColor(
            for interfaceStyle: UIUserInterfaceStyle
        ) -> UIColor {
            switch interfaceStyle {
            case .dark:
                return .black
            default:
                return UIColor(
                    red: 0.95,
                    green: 0.96,
                    blue: 0.98,
                    alpha: 1
                )
            }
        }

        private func accentColor(
            for interfaceStyle: UIUserInterfaceStyle
        ) -> UIColor {
            switch interfaceStyle {
            case .dark:
                return .white
            default:
                return .label
            }
        }
    }
}

private final class HotspotButton: UIButton {
    var hotspotID: UUID?
}

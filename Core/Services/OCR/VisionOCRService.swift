import CoreGraphics
import Foundation
import ImageIO
import Vision

struct VisionOCRService: OCRServiceProtocol {
    private static let recognitionQueue = DispatchQueue(
        label: "ScreenTranslator.VisionOCRService",
        qos: .userInitiated
    )

    let requestFactory: OCRRequestFactory

    init(requestFactory: OCRRequestFactory) {
        self.requestFactory = requestFactory
    }

    func recognizeText(in input: ScreenshotInput) async throws -> [OCRTextObservation] {
        try await withCheckedThrowingContinuation { continuation in
            Self.recognitionQueue.async {
                do {
                    let cgImage = try makeCGImage(from: input.imageData)
                    let request = requestFactory.makeRecognizeTextRequest()
                    let handler = VNImageRequestHandler(
                        cgImage: cgImage,
                        orientation: cgImageOrientation(for: input.orientation),
                        options: [:]
                    )

                    try handler.perform([request])
                    let recognizedObservations: [VNRecognizedTextObservation] = request.results ?? []
                    let observations = mapRecognizedObservations(
                        recognizedObservations,
                        inputSize: input.size
                    )
                    continuation.resume(returning: observations)
                } catch let error as AppError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: AppError.ocrFailure)
                }
            }
        }
    }

    private func makeCGImage(from imageData: Data) throws -> CGImage {
        guard
            let source = CGImageSourceCreateWithData(imageData as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw AppError.unsupportedImage
        }

        return cgImage
    }

    private func cgImageOrientation(
        for orientation: ScreenshotInput.Orientation
    ) -> CGImagePropertyOrientation {
        switch orientation {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        }
    }

    private func mapRecognizedObservations(
        _ observations: [VNRecognizedTextObservation],
        inputSize: CGSize
    ) -> [OCRTextObservation] {
        let positionedObservations: [PositionedObservation] = observations.compactMap {
            (observation: VNRecognizedTextObservation) -> PositionedObservation? in
            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }

            let recognizedText = candidate.string.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard recognizedText.isEmpty == false else {
                return nil
            }

            return PositionedObservation(
                originalText: recognizedText,
                boundingBox: projectBoundingBox(
                    observation.boundingBox,
                    inputSize: inputSize
                ),
                confidence: Double(candidate.confidence)
            )
        }

        let lineTolerance = max(inputSize.height * 0.012, 8)
        let sortedObservations = positionedObservations.sorted { lhs, rhs in
            if abs(lhs.boundingBox.minY - rhs.boundingBox.minY) > lineTolerance {
                return lhs.boundingBox.minY < rhs.boundingBox.minY
            }

            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }

        var currentLineIndex = -1
        var currentLineReferenceY: CGFloat?

        return sortedObservations.map { observation in
            if let referenceY = currentLineReferenceY {
                if abs(observation.boundingBox.minY - referenceY) > lineTolerance {
                    currentLineIndex += 1
                    currentLineReferenceY = observation.boundingBox.minY
                }
            } else {
                currentLineIndex = 0
                currentLineReferenceY = observation.boundingBox.minY
            }

            return OCRTextObservation(
                originalText: observation.originalText,
                boundingBox: observation.boundingBox,
                confidence: observation.confidence,
                lineIndex: currentLineIndex
            )
        }
    }

    private func projectBoundingBox(
        _ normalizedBoundingBox: CGRect,
        inputSize: CGSize
    ) -> CGRect {
        CGRect(
            x: normalizedBoundingBox.origin.x * inputSize.width,
            y: (1 - normalizedBoundingBox.origin.y - normalizedBoundingBox.height) * inputSize.height,
            width: normalizedBoundingBox.width * inputSize.width,
            height: normalizedBoundingBox.height * inputSize.height
        )
    }
}

private struct PositionedObservation {
    let originalText: String
    let boundingBox: CGRect
    let confidence: Double
}

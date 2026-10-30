import Vision
import ImageIO

// One Vision implementation for the app and DEBUG experiments. Never substitute alternate candidates.
func readScreenshotText(_ image: CGImage, orientation: CGImagePropertyOrientation = .up,
                        configure: ((VNRecognizeTextRequest) -> Void)? = nil) throws -> [OCRBlock] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
    request.usesLanguageCorrection = false
    configure?(request)
    try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
    let rotated = [.left, .leftMirrored, .right, .rightMirrored].contains(orientation)
    let width = CGFloat(rotated ? image.height : image.width), height = CGFloat(rotated ? image.width : image.height)
    return (request.results ?? []).enumerated().map { index, observation in
        let candidates = observation.topCandidates(3).map { TextCandidate(text:$0.string, confidence:$0.confidence) }
        let box = observation.boundingBox
        let rect = CGRect(x:box.minX * width, y:(1-box.maxY) * height, width:box.width * width, height:box.height * height)
        return OCRBlock(id:index, text:candidates.first?.text.trimmingCharacters(in:.whitespacesAndNewlines) ?? "",
                        rect:rect, observations:[index], confidence:candidates.first?.confidence ?? 0,
                        candidates:candidates, lineHeight:rect.height)
    }
}

func classifyScreenshotText(_ observations: [OCRBlock], size: CGSize) -> [OCRBlock] {
    let clock = observations.first { item in
        item.rect.midY < size.height*0.05 && item.rect.maxX < size.width*0.3
            && item.text.range(of:#"^\d{1,2}[:：]\d{2}$"#,options:.regularExpression) != nil
    }
    return observations.map { input in
        var item = input
        let r = item.rect
        let edgeDistance = min(r.minX,r.minY,size.width-r.maxX,size.height-r.maxY)
        let nearbyHeights = observations.filter {
            $0.id != item.id && abs($0.rect.midX-r.midX) < max(r.width,$0.rect.width)
                && abs($0.rect.midY-r.midY) < max(r.height,$0.rect.height)*4 && $0.rect.height > r.height
        }.map { $0.rect.height }.sorted()
        let typicalHeight = nearbyHeights.isEmpty ? r.height : nearbyHeights[nearbyHeights.count/2]
        if item.text.isEmpty { item.exclusion = "OCR_NOISE: empty candidate" }
        else if edgeDistance <= max(4,r.height*0.35) && (item.confidence < 0.75 || r.height < typicalHeight*0.8) {
            item.exclusion = "OCR_RECOGNITION: edge-clipped/incomplete"
        } else if let clock, abs(r.midY-clock.rect.midY) < clock.rect.height,
                  r.maxY < size.height*0.06 && (item.id == clock.id || r.minX > size.width*0.8 && r.width < size.width*0.15) {
            item.exclusion = "OCR_NOISE: clock-confirmed system status bar"
        } else if item.text.unicodeScalars.allSatisfy({ !CharacterSet.alphanumerics.contains($0) }) {
            item.exclusion = "OCR_NOISE: symbol-only observation"
        } else if item.confidence < 0.35 && item.text.count <= 2 {
            item.exclusion = "OCR_NOISE: ambiguous short candidate"
        }
        return item
    }
}

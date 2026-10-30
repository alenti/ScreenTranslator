#if DEBUG
import Foundation
import Vision
import ImageIO

@main struct OCRQualityExperiments {
    static func main() throws {
        let corpus = URL(fileURLWithPath:CommandLine.arguments[1]), out = URL(fileURLWithPath:CommandLine.arguments[2])
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        let cases = try FileManager.default.contentsOfDirectory(at:corpus,includingPropertiesForKeys:nil).filter { $0.hasDirectoryPath }.sorted { $0.path < $1.path }
        for folder in cases {
            let source = CGImageSourceCreateWithURL(folder.appendingPathComponent("original.png") as CFURL,nil)!
            let original = CGImageSourceCreateImageAtIndex(source,0,nil)!
            var rows: [[String:Any]] = []
            for name in ["baseline", "correction-on", "hans-en", "hans-en-correction", "revision3", "min-height-zero", "half-size", "double-size", "orientation-right", "orientation-roundtrip", "small-band-crop"] {
                let scale: CGFloat = name == "half-size" ? 0.5 : name == "double-size" ? 2 : 1
                var image = original
                if name == "orientation-roundtrip" {
                    let context = CGContext(data:nil,width:original.height,height:original.width,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
                    context.translateBy(x:CGFloat(original.height)/2,y:CGFloat(original.width)/2)
                    context.rotate(by:.pi/2)
                    context.draw(original,in:CGRect(x:-CGFloat(original.width)/2,y:-CGFloat(original.height)/2,width:CGFloat(original.width),height:CGFloat(original.height)))
                    image = context.makeImage()!
                }
                if name == "small-band-crop" {
                    image = original.cropping(to:CGRect(x:0,y:CGFloat(original.height)*0.85,width:CGFloat(original.width),height:CGFloat(original.height)*0.15))!
                }
                if scale != 1 {
                    let context = CGContext(data:nil,width:Int(CGFloat(image.width)*scale),height:Int(CGFloat(image.height)*scale),bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
                    context.interpolationQuality = .high
                    context.draw(image,in:CGRect(x:0,y:0,width:context.width,height:context.height)); image = context.makeImage()!
                }
                let start = Date()
                let observations = try readScreenshotText(image, orientation:name.hasPrefix("orientation-") ? .right : .up) { request in
                    if name.contains("correction") { request.usesLanguageCorrection = true }
                    if name.contains("hans-en") { request.recognitionLanguages = ["zh-Hans","en-US"] }
                    if name == "revision3" { request.revision = VNRecognizeTextRequestRevision3 }
                    if name == "min-height-zero" { request.minimumTextHeight = 0 }
                }
                let request = VNRecognizeTextRequest()
                rows.append(["configuration":name, "ocrMs":Date().timeIntervalSince(start)*1000,
                             "defaultRevision":request.revision,"supportedRevisions":VNRecognizeTextRequest.supportedRevisions.map { $0 },
                             "defaultMinimumTextHeight":request.minimumTextHeight,"scale":scale,"observations":observations.map(\.diagnostic),
                             "groups":groupText(observations).map(\.diagnostic)])
            }
            let baseline = rows.first { $0["configuration"] as? String == "baseline" }!["observations"] as! [[String:Any]]
            let oriented = rows.first { $0["configuration"] as? String == "orientation-roundtrip" }!["observations"] as! [[String:Any]]
            let baselineText = baseline.map { $0["text"] as! String }, orientedText = oriented.map { $0["text"] as! String }
            rows.append(["configuration":"orientation-roundtrip-check","sameText":baselineText == orientedText,"baselineCount":baseline.count,"orientedCount":oriented.count])
            let data = try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys])
            try data.write(to:out.appendingPathComponent(folder.lastPathComponent+".json"))
            print("OCR experiments: \(folder.lastPathComponent)")
        }
    }
}
#endif

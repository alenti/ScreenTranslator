import UIKit

struct OverlayPlacement {
    let id: Int
    let source: CGRect
    let rect: CGRect?
    let fontSize: CGFloat
    let padding: CGFloat
    let warning: String?
}

private func protectsTextGeometry(_ observation: OCRBlock) -> Bool {
    observation.exclusion == nil || observation.exclusion?.hasPrefix("OCR_RECOGNITION") == true || containsChinese(observation.text)
}

func overlayAttributes(_ fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
    let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byWordWrapping
    return [.font:UIFont.systemFont(ofSize:fontSize),.foregroundColor:UIColor.black,.paragraphStyle:paragraph]
}

// ponytail: O(n²) obstacle checks for screenshot-sized input; no general constraint solver.
func layoutScreenshotOverlays(_ blocks: [OCRBlock], observations: [OCRBlock], outputs: [Int:String], size: CGSize) -> [OverlayPlacement] {
    let bounds = CGRect(origin:.zero,size:size), scale = size.width/1170
    var placed: [OverlayPlacement] = []
    for block in readingOrdered(blocks) {
        guard let text = outputs[block.id] else { continue }
        let source = block.rect.intersection(bounds)
        let h = block.lineHeight > 0 ? block.lineHeight : source.height
        let padding = h < 32*scale ? 0 : min(4*scale,max(1*scale,h*0.06))
        let minimum = max(11*scale,min(18*scale,h*0.48))
        let preferred = max(minimum,min(44*scale,h*0.85))
        let obstacles = observations.filter { !block.observations.contains($0.id) && protectsTextGeometry($0) }.map(\.rect)
        let occupied = placed.compactMap(\.rect)
        func safe(_ rect: CGRect) -> Bool {
            bounds.contains(rect) && !obstacles.contains { rect.intersects($0) } && !occupied.contains { rect.intersects($0) }
        }
        // Small source-centered expansions, bounded to 2.5x source area and 0.75 line of extra height.
        var candidates: [CGRect] = []
        for extra in [CGSize.zero, CGSize(width:0,height:h*0.3), CGSize(width:source.width*0.25,height:0),
                      CGSize(width:source.width*0.5,height:0), CGSize(width:source.width*0.5,height:h*0.3),
                      CGSize(width:source.width*0.5,height:h*0.5),
                      CGSize(width:source.width,height:0), CGSize(width:source.width*0.5,height:h*0.75),
                      CGSize(width:source.width,height:h*0.6)] {
            let rect = source.insetBy(dx:-padding-extra.width/2,dy:-padding-extra.height/2)
            var clamped = rect.intersection(bounds)
            for obstacle in obstacles + occupied where clamped.intersects(obstacle) {
                var x0 = clamped.minX, x1 = clamped.maxX, y0 = clamped.minY, y1 = clamped.maxY
                if obstacle.minX >= source.maxX { x1 = min(x1,obstacle.minX-1) }
                else if obstacle.maxX <= source.minX { x0 = max(x0,obstacle.maxX+1) }
                // Vision line boxes can cross a neighboring paragraph boundary by less than one pixel.
                else if obstacle.minY >= source.maxY-1 { y1 = min(y1,obstacle.minY-1) }
                else if obstacle.maxY <= source.minY+1 { y0 = max(y0,obstacle.maxY+1) }
                clamped = CGRect(x:x0,y:y0,width:max(0,x1-x0),height:max(0,y1-y0))
            }
            if clamped.width*clamped.height <= source.width*source.height*2.5 && safe(clamped) { candidates.append(clamped) }
        }
        // Dense row OCR boxes may nearly touch: retain the exact source as a zero-padding candidate.
        if safe(source) { candidates.insert(source,at:0) }
        var winner: OverlayPlacement?
        for rect in candidates {
            let p = rect == source ? 0 : padding
            let inner = rect.insetBy(dx:p,dy:p)
            for font in Array(stride(from:preferred,through:minimum,by:-0.5)) + [minimum] {
                let measured = (text as NSString).boundingRect(with:CGSize(width:inner.width,height:.greatestFiniteMagnitude),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:overlayAttributes(font),context:nil)
                if ceil(measured.height) <= inner.height && ceil(measured.width) <= inner.width {
                    let width = max(min(source.width,rect.width),ceil(measured.width)+p*2)
                    let height = max(min(source.height,rect.height),ceil(measured.height)+p*2)
                    let tight = CGRect(x:min(max(source.midX-width/2,rect.minX),rect.maxX-width),
                                       y:min(max(source.midY-height/2,rect.minY),rect.maxY-height),width:width,height:height)
                    winner = OverlayPlacement(id:block.id,source:source,rect:tight,fontSize:font,padding:p,warning:nil)
                    break
                }
            }
            if winner != nil { break }
        }
        placed.append(winner ?? OverlayPlacement(id:block.id,source:source,rect:nil,fontSize:minimum,padding:padding,
                                                 warning:"LAYOUT_FIT: no readable placement without covering another text block"))
    }
    return placed
}

func renderScreenshotOverlays(_ image: UIImage, placements: [OverlayPlacement], outputs: [Int:String]) -> UIImage {
    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
    return UIGraphicsImageRenderer(size:image.size,format:format).image { context in
        image.draw(at:.zero)
        for panel in placements {
            guard let rect = panel.rect, let text = outputs[panel.id] else { continue }
            UIColor.white.setFill(); context.cgContext.fill(rect)
            (text as NSString).draw(with:rect.insetBy(dx:panel.padding,dy:panel.padding),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:overlayAttributes(panel.fontSize),context:nil)
        }
    }
}

func overlayMetrics(_ placements: [OverlayPlacement], observations: [OCRBlock], blocks: [OCRBlock], size: CGSize) -> [String:Any] {
    func area(_ rect: CGRect) -> CGFloat { rect.isNull ? 0 : max(0,rect.width)*max(0,rect.height) }
    let bounds = CGRect(origin:.zero,size:size), rendered = placements.filter { $0.rect != nil }
    var intersections = 0, unrelated = 0, violations = 0
    var rows: [[String:Any]] = []
    for (index,panel) in rendered.enumerated() {
        let rect = panel.rect!, ids = blocks.first { $0.id == panel.id }?.observations ?? [panel.id]
        let other = observations.filter { !ids.contains($0.id) && protectsTextGeometry($0) }
        let sourceOverlap = other.reduce(CGFloat(0)) { $0+area(rect.intersection($1.rect)) }
        let panelOverlap = rendered.dropFirst(index+1).reduce(CGFloat(0)) { partial,other in
            let overlap = area(rect.intersection(other.rect!)); if overlap > 0 { intersections += 1 }; return partial+overlap
        }
        if sourceOverlap > 0 { unrelated += 1 }
        if !bounds.contains(rect) { violations += 1 }
        rows.append(["id":panel.id,"sourceRect":rectValues(panel.source),"rect":rectValues(rect),"fontSize":panel.fontSize,
                     "sourceArea":area(panel.source),"renderedArea":area(rect),"areaRatio":area(rect)/max(1,area(panel.source)),
                     "outsideSourceArea":area(rect)-area(rect.intersection(panel.source)),"unrelatedSourceOverlapArea":sourceOverlap,
                     "panelOverlapArea":panelOverlap,"screenPercent":area(rect)/area(bounds)*100,"fit":true])
    }
    return ["panelIntersections":intersections,"unrelatedSourceOverlap":unrelated,"boundsViolations":violations,
            "fitFailures":placements.filter { $0.rect == nil }.count,"placements":rows,
            "failedPlacements":placements.filter { $0.rect == nil }.map { ["id":$0.id,"sourceRect":rectValues($0.source),"fit":false,"minimumFont":$0.fontSize,"reason":$0.warning ?? ""] as [String:Any] }]
}

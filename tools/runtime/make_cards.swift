#!/usr/bin/env swift
import AppKit
import Foundation

// Synthetic development inputs, never evidence of real app/screenshots.
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "../BuildArtifacts/oct2026/cards", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let width = 1170, height = 2532
let ink = NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.18, alpha: 1)
let accent = NSColor(calibratedRed: 0.96, green: 0.33, blue: 0.12, alpha: 1)
let paper = NSColor(calibratedWhite: 0.965, alpha: 1)
let secondary = NSColor(calibratedWhite: 0.46, alpha: 1)
var sources: [[String: Any]] = []
var regions: [[String: Any]] = []

func box(_ rect: CGRect, _ color: NSColor, radius: CGFloat = 22) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func text(_ value: String, _ rect: CGRect, size: CGFloat = 38, color: NSColor = ink,
          bold: Bool = false, record: Bool = true) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = 12
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular),
        .foregroundColor: color, .paragraphStyle: paragraph,
    ]
    let string = NSAttributedString(string: value, attributes: attributes)
    let measured = string.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                      options: [.usesLineFragmentOrigin, .usesFontLeading])
    precondition(measured.height <= rect.height + 1, "Text clips: \(value)")
    string.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    if record {
        regions.append(["source": value, "x": rect.minX, "y": rect.minY,
                        "width": rect.width, "height": measured.height, "font_size": size])
    }
}

func base(_ title: String, subtitle: String) {
    box(CGRect(x: 0, y: 0, width: width, height: height), paper, radius: 0)
    text("09:41", CGRect(x: 64, y: 42, width: 200, height: 60), size: 30, bold: true, record: false)
    text("5G   100%", CGRect(x: 890, y: 42, width: 230, height: 60), size: 26, record: false)
    text(title, CGRect(x: 64, y: 127, width: 1042, height: 72), size: 46, bold: true, record: false)
    text(subtitle, CGRect(x: 64, y: 208, width: 1042, height: 56), size: 25,
         color: secondary, record: false)
    text("Synthetic development card / no real app data", CGRect(x: 64, y: 2452, width: 1042, height: 48),
         size: 24, color: secondary, record: false)
}

func make(_ filename: String, category: String, draw: () -> Void) throws {
    regions = []
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    let data = bitmap.representation(using: .png, properties: [:])!
    try data.write(to: output.appendingPathComponent(filename), options: .atomic)
    let decoded = NSBitmapImageRep(data: data)!
    precondition(decoded.pixelsWide == width && decoded.pixelsHigh == height)
    precondition(!regions.isEmpty)
    sources.append(["file": filename, "category": category, "provenance": "synthetic",
                    "width": width, "height": height, "byte_count": data.count,
                    "text_regions": regions])
    print("\(filename): \(regions.count) authored source regions, \(data.count) bytes")
}

try make("A_product_ui.png", category: "short_product_ui") {
    base("LIGHT HOME", subtitle: "Development product page")
    box(CGRect(x: 64, y: 314, width: 1042, height: 890), .white)
    box(CGRect(x: 157, y: 580, width: 856, height: 380), NSColor(calibratedWhite: 0.86, alpha: 1), radius: 150)
    box(CGRect(x: 177, y: 587, width: 816, height: 340), NSColor(calibratedRed: 1, green: 0.92, blue: 0.69, alpha: 1), radius: 150)
    box(CGRect(x: 217, y: 625, width: 736, height: 255), NSColor(calibratedRed: 1, green: 0.97, blue: 0.87, alpha: 1), radius: 125)
    text("暖白光吸顶灯", CGRect(x: 86, y: 1280, width: 996, height: 90), size: 58, bold: true)
    text("柔和照明，适合客厅与卧室", CGRect(x: 86, y: 1390, width: 996, height: 84), size: 42)
    text("¥135", CGRect(x: 86, y: 1510, width: 996, height: 100), size: 68, color: accent, bold: true)
    box(CGRect(x: 64, y: 1660, width: 1042, height: 485), .white)
    text("已选：暖白光 3000K，54W", CGRect(x: 90, y: 1706, width: 988, height: 84), size: 42)
    text("尺寸：260×80cm", CGRect(x: 90, y: 1820, width: 988, height: 84), size: 42)
    text("库存充足，现货发出", CGRect(x: 90, y: 1934, width: 988, height: 84), size: 42)
    text("含安装配件", CGRect(x: 90, y: 2048, width: 988, height: 84), size: 42)
    box(CGRect(x: 64, y: 2260, width: 512, height: 135), NSColor(calibratedRed: 1, green: 0.69, blue: 0.16, alpha: 1))
    box(CGRect(x: 594, y: 2260, width: 512, height: 135), accent)
    text("加入购物车", CGRect(x: 145, y: 2301, width: 355, height: 78), size: 48, color: .white, bold: true)
    text("立即购买", CGRect(x: 743, y: 2301, width: 318, height: 78), size: 48, color: .white, bold: true)
}

try make("B_dense_commerce.png", category: "dense_commerce") {
    base("ORDER DETAILS", subtitle: "Development checkout / 18 independent Chinese rows")
    let rows = [
        "商品名称：现代简约吸顶灯", "已选：暖白光 3000K", "额定功率：54W", "产品尺寸：260×80cm",
        "产品型号：ST-54W", "接口类型：USB-C", "单价：¥135", "购买数量：20件", "合计金额：¥2700",
        "包装方式：单独套袋", "四角保护：加厚泡沫", "外箱要求：坚固防水", "发货地点：广州仓库",
        "预计发货：今天", "运输方式：国际物流", "收货要求：检查外箱", "售后服务：补发配件",
        "订单备注：外箱注明货物名称",
    ]
    for (index, row) in rows.enumerated() {
        let y = CGFloat(320 + index * 112)
        box(CGRect(x: 64, y: y, width: 1042, height: 92), .white, radius: 14)
        text(row, CGRect(x: 92, y: y + 18, width: 986, height: 69), size: 36)
    }
}

try make("C_seller_chat.png", category: "seller_chat") {
    base("SELLER CHAT", subtitle: "Development messages / no conversation context injection")
    let messages: [(String, CGFloat, CGFloat, Bool)] = [
        ("您好，我收到货后发现有一个灯不亮，可以补发配件吗？", 350, 420, true),
        ("可以的，麻烦拍一下故障视频，我们今天给您补发。", 72, 920, false),
        ("好的，我会拍视频，请补发安装配件。", 350, 1450, true),
        ("收到，请确认订单型号 ST-54W 和收货地址。", 72, 1890, false),
    ]
    for (message, x, y, customer) in messages {
        let color = customer ? NSColor(calibratedRed: 0.82, green: 0.94, blue: 0.76, alpha: 1) : .white
        box(CGRect(x: x, y: y, width: 746, height: 300), color, radius: 28)
        text(message, CGRect(x: x + 35, y: y + 40, width: 676, height: 235), size: 43)
    }
    box(CGRect(x: 64, y: 2290, width: 1042, height: 95), .white, radius: 18)
    text("Message", CGRect(x: 94, y: 2315, width: 850, height: 60), size: 30,
         color: secondary, record: false)
}

try make("D_packaging_spec.png", category: "long_paragraph_specification") {
    base("SHIPPING NOTES", subtitle: "Development packaging / mixed identifiers and exact values")
    box(CGRect(x: 64, y: 324, width: 1042, height: 2080), .white)
    text("国际运输包装要求", CGRect(x: 106, y: 375, width: 958, height: 95), size: 52, bold: true)
    text("这批货物后续还有国际运输，请务必做好非常牢固的包装，并在外箱注明货物名称。",
         CGRect(x: 106, y: 540, width: 958, height: 290), size: 42)
    text("这是一批准备发往海外仓的照明产品，共有20件。每件产品都需要单独套袋，并用加厚泡沫保护四角。装箱后请再次核对型号、数量和配件清单，确保外箱标签清晰、防水，避免在国际运输途中因挤压或受潮造成损坏。",
         CGRect(x: 106, y: 925, width: 958, height: 445), size: 40)
    text("产品规格", CGRect(x: 106, y: 1480, width: 958, height: 90), size: 48, bold: true)
    text("已选：暖白光 3000K，54W，260×80cm；20件",
         CGRect(x: 106, y: 1640, width: 958, height: 170), size: 42)
    text("型号：ST-54W；接口：USB-C；单价：¥135",
         CGRect(x: 106, y: 1885, width: 958, height: 170), size: 42)
    text("签收前请检查外箱，如有破损请拍照并联系卖家。",
         CGRect(x: 106, y: 2160, width: 958, height: 175), size: 40)
}

precondition(sources.count == 4)
let manifest: [String: Any] = [
    "schema_version": 1, "provenance": "synthetic", "coordinate_origin": "top_left_pixels",
    "description": "User-authorized AppKit-authored Chinese development cards. No real application capture, real personal data, or translated strings.",
    "generator": "tools/runtime/make_cards.swift", "fixtures": sources,
]
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    .write(to: output.appendingPathComponent("source_manifest.json"), options: .atomic)
print("Manifest: \(output.appendingPathComponent("source_manifest.json").path)")

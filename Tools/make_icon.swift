// Cắt icon màu từ bản thiết kế và xuất bộ .iconset.
// Dùng: swift Tools/make_icon.swift icon.png build/AppIcon.iconset
import Cocoa

let args = CommandLine.arguments
guard args.count == 3, let src = NSImage(contentsOfFile: args[1]),
      let cg = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("Dùng: make_icon.swift <icon.png> <out.iconset>"); exit(1)
}
let W = cg.width, H = cg.height

// Đọc điểm ảnh RGBA
var px = [UInt8](repeating: 0, count: W * H * 4)
let ctx = CGContext(data: &px, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))

// Hộp bao của các điểm ảnh xanh dương (icon màu nằm ở nửa trên bên trái)
var minX = W, maxX = 0, minY = H, maxY = 0
for y in 0..<(H * 55 / 100) {
    for x in 0..<(W / 2) {
        let i = (y * W + x) * 4
        let r = Int(px[i]), b = Int(px[i + 2])
        if b > 180 && b - r > 100 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
}
let side = min(maxX - minX, maxY - minY) + 1
let inset = 3
let crop = CGRect(x: minX + inset, y: minY + inset, width: side - 2 * inset, height: side - 2 * inset)
print("Hộp icon: x=\(minX)…\(maxX) y=\(minY)…\(maxY)")
guard let icon = cg.cropping(to: crop) else { print("Không cắt được"); exit(1) }

func render(_ size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let g = NSGraphicsContext.current!.cgContext
    g.interpolationQuality = .high
    // Chuẩn macOS: thân icon chiếm 824/1024, chừa lề cho bóng
    let body = CGFloat(size) * 824 / 1024
    let rect = CGRect(x: (CGFloat(size) - body) / 2, y: (CGFloat(size) - body) / 2, width: body, height: body)
    let path = CGPath(roundedRect: rect, cornerWidth: body * 0.235, cornerHeight: body * 0.235, transform: nil)
    g.saveGState()
    g.setShadow(offset: CGSize(width: 0, height: -CGFloat(size) * 0.01), blur: CGFloat(size) * 0.025,
                color: NSColor.black.withAlphaComponent(0.3).cgColor)
    g.addPath(path); g.setFillColor(NSColor.black.cgColor); g.fillPath()
    g.restoreGState()
    g.saveGState()
    g.addPath(path); g.clip()
    g.draw(icon, in: rect)
    g.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try? FileManager.default.createDirectory(atPath: args[2], withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(args[2])/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(args[2])/icon_\(base)x\(base)@2x.png"))
}

// Draws the "Dot Bud" app icon and writes Resources/AppIcon.icns and docs/icon.png.
//
//   swift scripts/make-icon.swift
//
// Design (1024 master on the macOS grid): an 824×824 smoked body at (100, 100)
// with a 185.4 corner radius, a faint "see-through" dot grid, two hairline rings,
// four screw heads and an inner keyline. The mark is the menu bar glyph ×34 with
// a red driver dot. 16 and 32 px use a simplified master: no grid, rings or
// screws, and dots 22% larger so they survive.

import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// The menu bar glyph on its 18×18 grid (y down): ring of 8, stem of 3, driver.
let ringCenter = CGPoint(x: 7.5, y: 7.0)
var glyphDots: [(CGPoint, CGFloat, Bool)] = (0..<8).map { i in
    let a = CGFloat(i) * .pi / 4
    return (CGPoint(x: 7.5 + 5.2 * sin(a), y: 7.0 - 5.2 * cos(a)), 75 / 34, false)
}
glyphDots += [10.3, 13.5, 16.7].map { (CGPoint(x: 12.7, y: $0), 75 / 34, false) }
glyphDots.append((ringCenter, 136 / 34, true))

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    let cg = ctx.cgContext
    let s = CGFloat(pixels) / 1024
    let simple = pixels <= 32
    // Work in 1024 units with y pointing down.
    cg.translateBy(x: 0, y: CGFloat(pixels))
    cg.scaleBy(x: s, y: -s)

    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185.4, cornerHeight: 185.4, transform: nil)

    // Drop shadow (y +10, blur 20, black 30%).
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 20 * s, color: color(0x000000, 0.3))
    cg.addPath(bodyPath)
    cg.setFillColor(color(0x1E1E1F))
    cg.fillPath()
    cg.restoreGState()

    // Body: vertical gradient plus a soft top glow.
    cg.saveGState()
    cg.addPath(bodyPath)
    cg.clip()
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let gradient = CGGradient(colorsSpace: space, colors: [color(0x2E2E30), color(0x0E0E0F)] as CFArray,
                              locations: [0, 1])!
    cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: body.minY), end: CGPoint(x: 0, y: body.maxY), options: [])
    let glow = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF, 0.14), color(0xFFFFFF, 0)] as CFArray,
                          locations: [0, 1])!
    cg.drawLinearGradient(glow, start: CGPoint(x: 0, y: body.minY), end: CGPoint(x: 0, y: body.minY + 380), options: [])

    if !simple {
        // See-through layer: a 46 px dot grid at 7%.
        cg.setFillColor(color(0xFFFFFF, 0.07))
        var y = body.minY + 23
        while y < body.maxY {
            var x = body.minX + 23
            while x < body.maxX {
                cg.fillEllipse(in: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5))
                x += 46
            }
            y += 46
        }
        // Two hairline rings around the mark.
        let markCenter = CGPoint(x: 512, y: 435)
        cg.setStrokeColor(color(0xFFFFFF, 0.07))
        cg.setLineWidth(2)
        for r: CGFloat in [262, 350] {
            cg.strokeEllipse(in: CGRect(x: markCenter.x - r, y: markCenter.y - r, width: 2 * r, height: 2 * r))
        }
        // Four screw heads.
        for (x, y) in [(170.0, 170.0), (854, 170), (170, 854), (854, 854)] {
            let c = CGPoint(x: x, y: y)
            cg.setFillColor(color(0xFFFFFF, 0.06))
            cg.fillEllipse(in: CGRect(x: c.x - 13, y: c.y - 13, width: 26, height: 26))
            cg.setStrokeColor(color(0xFFFFFF, 0.14))
            cg.setLineWidth(2)
            cg.strokeEllipse(in: CGRect(x: c.x - 13, y: c.y - 13, width: 26, height: 26))
            cg.move(to: CGPoint(x: c.x - 8, y: c.y))
            cg.addLine(to: CGPoint(x: c.x + 8, y: c.y))
            cg.strokePath()
        }
    }
    cg.restoreGState()

    // 3 px inner keyline.
    cg.saveGState()
    cg.addPath(CGPath(roundedRect: body.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 184, cornerHeight: 184, transform: nil))
    cg.setStrokeColor(color(0xFFFFFF, 0.10))
    cg.setLineWidth(3)
    cg.strokePath()
    cg.restoreGState()

    // The mark: glyph ×34, ring centre at (512, 435).
    let scale: CGFloat = 34
    let offset = CGPoint(x: 512 - ringCenter.x * scale, y: 435 - ringCenter.y * scale)
    let grow: CGFloat = simple ? 1.22 : 1
    for (center, diameter, isDriver) in glyphDots {
        let d = diameter * scale * grow
        let c = CGPoint(x: offset.x + center.x * scale, y: offset.y + center.y * scale)
        cg.setFillColor(isDriver ? color(0xE8392C) : color(0xFFFFFF))
        cg.fillEllipse(in: CGRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d))
    }
    ctx.flushGraphics()
    return rep
}

func png(_ rep: NSBitmapImageRep, to url: URL) throws {
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try png(drawIcon(pixels: base), to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(drawIcon(pixels: base * 2), to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let icns = root.appendingPathComponent("Resources/AppIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else { fatalError("iconutil failed") }

try png(drawIcon(pixels: 256), to: root.appendingPathComponent("docs/icon.png"))
print("Wrote \(icns.path) and docs/icon.png")

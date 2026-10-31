import AppKit

// Original code-native installer artwork, in points with a 2x bitmap.
let width = 640, height = 400
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * 2,
    pixelsHigh: height * 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = NSSize(width: width, height: height)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let cream = NSColor(calibratedRed: 0.973, green: 0.965, blue: 0.937, alpha: 1)
let pine = NSColor(calibratedRed: 0.086, green: 0.235, blue: 0.216, alpha: 1)
let muted = NSColor(calibratedRed: 0.36, green: 0.41, blue: 0.38, alpha: 1)
cream.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

func text(_ value: String, x: CGFloat, top: CGFloat, size: CGFloat,
          weight: NSFont.Weight = .regular, color: NSColor) {
    (value as NSString).draw(at: NSPoint(x: x, y: CGFloat(height) - top - size * 1.35),
        withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
}

text("Lidune · 合留", x: 44, top: 32, size: 23, weight: .semibold, color: pine)
text("拖入「应用程序」即可安装", x: 44, top: 80, size: 17, weight: .medium, color: pine)
text("Drag Lidune to Applications to install.", x: 44, top: 108, size: 12, color: muted)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 280, y: CGFloat(height - 218)))
arrow.line(to: NSPoint(x: 360, y: CGFloat(height - 218)))
arrow.move(to: NSPoint(x: 349, y: CGFloat(height - 207)))
arrow.line(to: NSPoint(x: 360, y: CGFloat(height - 218)))
arrow.line(to: NSPoint(x: 349, y: CGFloat(height - 229)))
arrow.lineWidth = 2.5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
pine.withAlphaComponent(0.55).setStroke()
arrow.stroke()

text("安装后，点击菜单栏猫头鹰开始使用。", x: 44, top: 308, size: 11, color: muted)
text("After installing, open Lidune from Applications.", x: 44, top: 328, size: 11, color: muted)
let version = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : ""
text("\(version) · Apple Silicon", x: 432, top: 37, size: 11, color: muted)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .tiff, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))

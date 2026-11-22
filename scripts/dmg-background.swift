import AppKit

// Original code-native installer artwork, in points with a 2x bitmap.
let width = 640, height = 400
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * 2,
    pixelsHigh: height * 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = NSSize(width: width, height: height)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let cream = NSColor(srgbRed: 0.980, green: 0.978, blue: 0.967, alpha: 1)
let slate = NSColor(srgbRed: 0.08, green: 0.10, blue: 0.14, alpha: 1)
let cobalt = NSColor(srgbRed: 0.15, green: 0.35, blue: 0.80, alpha: 1)
let muted = NSColor(srgbRed: 0.34, green: 0.38, blue: 0.45, alpha: 1)
cream.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

func text(_ value: String, x: CGFloat, top: CGFloat, size: CGFloat,
          weight: NSFont.Weight = .regular, color: NSColor) {
    (value as NSString).draw(at: NSPoint(x: x, y: CGFloat(height) - top - size * 1.35),
        withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
}

text("盖盖 · LidLid", x: 44, top: 32, size: 23, weight: .semibold, color: slate)
text("拖入「应用程序」即可安装", x: 44, top: 80, size: 17, weight: .medium, color: slate)
text("Drag LidLid to Applications to install.", x: 44, top: 108, size: 12, color: muted)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 280, y: CGFloat(height - 218)))
arrow.line(to: NSPoint(x: 360, y: CGFloat(height - 218)))
arrow.move(to: NSPoint(x: 349, y: CGFloat(height - 207)))
arrow.line(to: NSPoint(x: 360, y: CGFloat(height - 218)))
arrow.line(to: NSPoint(x: 349, y: CGFloat(height - 229)))
arrow.lineWidth = 2.5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
cobalt.withAlphaComponent(0.75).setStroke()
arrow.stroke()

text("安装后，请从「应用程序」打开盖盖。", x: 44, top: 308, size: 11, color: muted)
text("After installing, open LidLid from Applications.", x: 44, top: 328, size: 11, color: muted)
let version = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : ""
text("\(version) · Apple Silicon", x: 432, top: 37, size: 11, color: muted)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .tiff, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))

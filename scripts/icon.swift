import AppKit

let target = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let background = NSBezierPath(roundedRect: NSRect(x: 50, y: 50, width: 924, height: 924), xRadius: 210, yRadius: 210)
NSColor(calibratedRed: 0.08, green: 0.39, blue: 0.34, alpha: 1).setFill(); background.fill()
let screen = NSBezierPath(roundedRect: NSRect(x: 245, y: 365, width: 534, height: 350), xRadius: 32, yRadius: 32)
NSColor(calibratedWhite: 1, alpha: 0.94).setStroke(); screen.lineWidth = 25; screen.stroke()
let base = NSBezierPath()
base.move(to: NSPoint(x: 205, y: 325)); base.line(to: NSPoint(x: 819, y: 325))
base.lineCapStyle = .round; base.lineWidth = 27; base.stroke()
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedDigitSystemFont(ofSize: 215, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.95)
]
let text = "1" as NSString
let textSize = text.size(withAttributes: attrs)
text.draw(at: NSPoint(x: (1024 - textSize.width) / 2, y: 415), withAttributes: attrs)
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: target)

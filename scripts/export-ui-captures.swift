import AppKit

// Export genuine native captures without replacing, retouching or synthesizing UI.
// The reopened teaching frame uses the generic Off appearance, not hardware evidence.
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let locales = [("zh-Hans", "zh-CN", "zh"), ("en-US", "en", "en")]
var dimensions: [String: [String: [Int]]] = [:]
for (store, docs, web) in locales {
    var sizes: [String: [Int]] = [:]
    for state in ["on", "off", "options"] {
        let source = root.appendingPathComponent("docs/app-store/captures/\(store)/\(state).png")
        let data = try Data(contentsOf: source)
        let input = NSBitmapImageRep(data: data)!
        let image = NSImage(data: data)!
        let w = input.pixelsWide, h = input.pixelsHigh
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSColor(srgbRed: 0.98, green: 0.98, blue: 0.969, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: w, height: h).fill()
        image.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()
        let jpeg = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .jpeg, properties: [.compressionFactor: 0.92])!
        var targets = [
            "docs/assets/\(docs)/demo-\(state).jpg",
            "docs/assets/\(docs)/interface-\(state).jpg",
            "website/public/assets/interface-\(state)-\(web).jpg"
        ]
        if state == "off" {
            targets += ["docs/assets/\(docs)/demo-reopened.jpg", "website/public/assets/interface-reopened-\(web).jpg"]
        }
        for target in targets { try jpeg.write(to: root.appendingPathComponent(target)) }
        sizes[state] = [w, h]
    }
    dimensions[web] = sizes
}
try JSONSerialization.data(withJSONObject: dimensions, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent("website/ui-sizes.json"))
print("Exported localized native screenshots and exact image dimensions.")


import AppKit

// The approved full-bleed 1024px master is shared by the app, website and listing.
// Legacy macOS ICNS needs its own inset rounded silhouette; keep the master square.
let args = CommandLine.arguments
guard args.count == 4, ["iconset", "public"].contains(args[1]) else {
    fatalError("Usage: swift export-brand-assets.swift iconset|public MASTER.png OUTPUT_DIRECTORY")
}
let source = URL(fileURLWithPath: args[2])
let destination = URL(fileURLWithPath: args[3])
guard let data = try? Data(contentsOf: source), let master = NSBitmapImageRep(data: data),
      master.pixelsWide == 1024, master.pixelsHigh == 1024, !master.hasAlpha,
      let image = NSImage(data: data) else {
    fatalError("Expected an opaque 1024 × 1024 master")
}
func export(_ pixels: Int, _ relative: String, rounded: Bool, inset: CGFloat = 0) throws {
    let transparent = rounded
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
        bytesPerRow: pixels * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: transparent ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current?.imageInterpolation = .high
    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
        .insetBy(dx: CGFloat(pixels) * inset, dy: CGFloat(pixels) * inset)
    if rounded { NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.22, yRadius: rect.height * 0.22).addClip() }
    image.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    let target = destination.appendingPathComponent(relative)
    try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
    try NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!.write(to: target)
}
if args[1] == "iconset" {
    for size in [16, 32, 128, 256, 512] {
        try export(size, "icon_\(size)x\(size).png", rounded: true, inset: 0.055)
        try export(size * 2, "icon_\(size)x\(size)@2x.png", rounded: true, inset: 0.055)
    }
} else {
    try export(512, "docs/assets/app-icon.png", rounded: true)
    try export(256, "website/public/assets/icon.png", rounded: true)
    try export(32, "website/public/assets/favicon.png", rounded: true)
    try export(180, "website/public/assets/apple-touch-icon.png", rounded: false)
}
print("Exported \(args[1]) brand assets from approved master.")


import AppKit

/// Compile with OwlMenuSymbol.swift to render the exact production vectors.
@main
struct MenuSymbolPreview {
    static func main() throws {
        let output = CommandLine.arguments[1]
        let chinese = CommandLine.arguments.count < 3 || CommandLine.arguments[2] == "zh"
        let width = 900, height = 520
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * 2,
            pixelsHigh: height * 2, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let ink = NSColor(calibratedRed: 0.08, green: 0.19, blue: 0.17, alpha: 1)
        let secondary = NSColor(calibratedWhite: 0.43, alpha: 1)
        func rect(_ x: CGFloat, _ top: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
            NSRect(x: x, y: CGFloat(height) - top - h, width: w, height: h)
        }
        func text(_ string: String, _ x: CGFloat, _ top: CGFloat, _ size: CGFloat,
                  _ color: NSColor, _ weight: NSFont.Weight = .regular) {
            (string as NSString).draw(at: NSPoint(x: x, y: CGFloat(height) - top - size * 1.4),
                withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
        }
        NSColor(calibratedRed: 0.975, green: 0.973, blue: 0.956, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        text(chinese ? "盖盖 · 菜单栏图标" : "LidLid · Menu-bar icons", 54, 28, 24, ink, .semibold)
        text(chinese ? "闭眼休息，睁眼工作。" : "Eyes closed to rest. Eyes wide open to work.", 54, 65, 13, secondary)
        text(chinese ? "已关闭 / Off" : "Off", 215, 103, 17, ink, .medium)
        text(chinese ? "已开启 / On" : "On", 615, 103, 17, ink, .medium)
        OwlMenuSymbol.draw(.off, in: rect(238, 145, 64, 64), color: ink)
        OwlMenuSymbol.draw(.on, in: rect(638, 145, 64, 64), color: ink)
        text(chinese ? "轻轮廓 · 闭眼" : "Light outline · Closed eyes", 208, 228, 13, secondary)
        text(chinese ? "实心轮廓 · 大圆眼" : "Solid silhouette · Wide eyes", 596, 228, 13, secondary)
        for dark in [false, true] {
            let top: CGFloat = dark ? 390 : 294
            (dark ? NSColor(calibratedWhite: 0.12, alpha: 1) : NSColor(calibratedWhite: 0.90, alpha: 1)).setFill()
            NSBezierPath(roundedRect: rect(54, top, 792, 72), xRadius: 14, yRadius: 14).fill()
            let foreground: NSColor = dark ? .white : .black
            text(chinese ? (dark ? "深色菜单栏" : "浅色菜单栏") : (dark ? "Dark menu bar" : "Light menu bar"),
                78, top + 25, 12, foreground.withAlphaComponent(0.75))
            OwlMenuSymbol.draw(.off, in: rect(260, top + 27, 18, 18), color: foreground)
            OwlMenuSymbol.draw(.on, in: rect(660, top + 27, 18, 18), color: foreground)
            text(chinese ? "关闭" : "Off", 292, top + 25, 12, foreground)
            text(chinese ? "开启" : "On", 692, top + 25, 12, foreground)
        }
        text(chinese ? "下方以 18 pt 实际尺寸绘制，使用与应用相同的矢量代码。" : "18 pt at actual size below, rendered from the app's production vector code.",
            54, 483, 11, secondary)
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
    }
}

import AppKit

/// Compile with GuardianMenuSymbol.swift to render the exact production vectors.
@main
struct MenuSymbolPreview {
    static func main() throws {
        let output = CommandLine.arguments[1]
        let chinese = CommandLine.arguments.count < 3 || CommandLine.arguments[2] == "zh"
        let width = 900, height = 500
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
        text(chinese ? "实心表示合盖不休眠，蓝色圆点表示开盖不休眠。"
                     : "Solid fill marks closed-lid sessions. A blue dot marks open-lid keep-awake.", 54, 65, 13, secondary)
        let columns: [(GuardianMenuState, CGFloat, String, String)] = [
            (.off, 153, chinese ? "都关闭" : "Both off", chinese ? "闭眼轮廓" : "Resting outline"),
            (.on, 351, chinese ? "仅合盖" : "Closed lid only", chinese ? "实心" : "Solid"),
            (.openLid, 549, chinese ? "仅开盖" : "Open lid only", chinese ? "蓝色轮廓 · 圆点" : "Blue outline + dot"),
            (.both, 747, chinese ? "两个都开" : "Both on", chinese ? "蓝色实心 · 圆点" : "Blue solid + dot")
        ]
        func centered(_ value: String, _ center: CGFloat, _ top: CGFloat, _ size: CGFloat,
                      _ color: NSColor, _ weight: NSFont.Weight = .regular) {
            let font = NSFont.systemFont(ofSize: size, weight: weight)
            let w = (value as NSString).size(withAttributes: [.font: font]).width
            text(value, center - w / 2, top, size, color, weight)
        }
        for (state, center, title, detail) in columns {
            centered(title, center, 103, 17, ink, .medium)
            GuardianMenuSymbol.draw(state, in: rect(center - 34, 145, 68, 68),
                                    color: state.openLidEnabled ? GuardianMenuSymbol.openLidColor : ink)
            centered(detail, center, 228, 13, secondary)
        }
        for dark in [false, true] {
            let top: CGFloat = dark ? 376 : 292
            (dark ? NSColor(calibratedWhite: 0.12, alpha: 1) : NSColor(calibratedWhite: 0.90, alpha: 1)).setFill()
            NSBezierPath(roundedRect: rect(54, top, 792, 72), xRadius: 14, yRadius: 14).fill()
            let foreground: NSColor = dark ? .white : .black
            text(chinese ? (dark ? "深色菜单栏" : "浅色菜单栏") : (dark ? "Dark menu bar" : "Light menu bar"),
                78, top + 25, 12, foreground.withAlphaComponent(0.75))
            for (index, column) in columns.enumerated() {
                let (state, _, title, _) = column
                let x = CGFloat(246 + index * 146)
                GuardianMenuSymbol.draw(state, in: rect(x, top + 27, 18, 18),
                                        color: state.openLidEnabled ? GuardianMenuSymbol.openLidColor : foreground)
                text(title, x + 27, top + 25, 12, foreground)
            }
        }
        text(chinese ? "浅色和深色行按菜单栏实际尺寸 18 pt 绘制。" : "Light and dark rows show the icons at their actual 18 pt menu-bar size.",
            54, 468, 11, secondary)
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
    }
}

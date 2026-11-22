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
        let ink = NSColor(srgbRed: 0.08, green: 0.10, blue: 0.14, alpha: 1)
        let secondary = NSColor(srgbRed: 0.34, green: 0.38, blue: 0.45, alpha: 1)
        let cobaltLight = NSColor(srgbRed: 0.15, green: 0.37, blue: 0.84, alpha: 1)
        let cobaltDark = NSColor(srgbRed: 0.39, green: 0.64, blue: 1.0, alpha: 1)
        func rect(_ x: CGFloat, _ top: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
            NSRect(x: x, y: CGFloat(height) - top - h, width: w, height: h)
        }
        func text(_ string: String, _ x: CGFloat, _ top: CGFloat, _ size: CGFloat,
                  _ color: NSColor, _ weight: NSFont.Weight = .regular) {
            (string as NSString).draw(at: NSPoint(x: x, y: CGFloat(height) - top - size * 1.4),
                withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
        }
        NSColor(srgbRed: 0.980, green: 0.978, blue: 0.967, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        text(chinese ? "盖盖 · 菜单栏图标" : "LidLid · Menu-bar icons", 54, 28, 24, ink, .semibold)
        text(chinese ? "实心表示合盖不休眠，右上蓝点表示开盖不休眠，左上圆环表示屏幕常亮。"
                     : "Solid fill = closed-lid awake. Top-right blue dot = open-lid. Top-left ring = display awake.", 54, 65, 13, secondary)
        let columns: [(GuardianMenuState, Bool, CGFloat, String, String)] = [
            (.off, false, 126, chinese ? "已关闭" : "Off", chinese ? "闭眼轮廓" : "Resting outline"),
            (.on, false, 288, chinese ? "合盖不休眠" : "Closed-lid", chinese ? "实心" : "Solid"),
            (.openLid, false, 450, chinese ? "开盖不休眠" : "Open-lid", chinese ? "蓝轮廓 · 点" : "Blue + dot"),
            (.off, true, 612, chinese ? "屏幕常亮" : "Display awake", chinese ? "睁眼 · 环" : "Awake + ring"),
            (.both, false, 774, chinese ? "合盖 + 开盖" : "Both lid modes", chinese ? "蓝实心 · 点" : "Blue solid + dot")
        ]
        func centered(_ value: String, _ center: CGFloat, _ top: CGFloat, _ size: CGFloat,
                      _ color: NSColor, _ weight: NSFont.Weight = .regular) {
            let font = NSFont.systemFont(ofSize: size, weight: weight)
            let w = (value as NSString).size(withAttributes: [.font: font]).width
            text(value, center - w / 2, top, size, color, weight)
        }
        for (state, displayAwake, center, title, detail) in columns {
            centered(title, center, 103, 15.5, ink, .medium)
            GuardianMenuSymbol.draw(state, displayAwake: displayAwake, in: rect(center - 32, 146, 64, 64),
                                    color: state.openLidEnabled ? cobaltLight : ink)
            centered(detail, center, 228, 12.5, secondary)
        }
        for dark in [false, true] {
            let top: CGFloat = dark ? 376 : 292
            (dark ? NSColor(srgbRed: 0.10, green: 0.12, blue: 0.15, alpha: 1)
                  : NSColor(srgbRed: 0.92, green: 0.93, blue: 0.95, alpha: 1)).setFill()
            NSBezierPath(roundedRect: rect(54, top, 792, 72), xRadius: 14, yRadius: 14).fill()
            let foreground: NSColor = dark ? .white : ink
            let blue: NSColor = dark ? cobaltDark : cobaltLight
            text(chinese ? (dark ? "深色菜单栏" : "浅色菜单栏") : (dark ? "Dark menu bar" : "Light menu bar"),
                76, top + 25, 12, foreground.withAlphaComponent(0.75))
            for (index, column) in columns.enumerated() {
                let (state, displayAwake, _, title, _) = column
                let x = CGFloat(200 + index * 128)
                GuardianMenuSymbol.draw(state, displayAwake: displayAwake, in: rect(x, top + 27, 18, 18),
                                        color: state.openLidEnabled ? blue : foreground)
                text(title, x + 24, top + 26, 11.5, foreground)
            }
        }
        text(chinese ? "浅色和深色行按菜单栏实际尺寸 18 pt 绘制。" : "Light and dark rows show the icons at their actual 18 pt menu-bar size.",
            54, 468, 11, secondary)
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
    }
}

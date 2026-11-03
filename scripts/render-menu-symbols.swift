import AppKit

/// Compile with GuardianMenuSymbol.swift to render the exact production vectors.
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
        text(chinese ? "黑白区分本次合盖，蓝色表示开盖保持唤醒。" : "Monochrome for one lid close. Blue for open-lid keep-awake.", 54, 65, 13, secondary)
        let columns: [(GuardianMenuState, CGFloat, String, String)] = [
            (.off, 190, chinese ? "已关闭" : "Off", chinese ? "闭眼 · 正常休眠" : "Closed eyes · Normal sleep"),
            (.on, 450, chinese ? "本次合盖" : "Closed-lid session", chinese ? "黑白 · 睁眼" : "Monochrome · Awake"),
            (.openLid, 710, chinese ? "开盖不休眠" : "Open-lid keep-awake", chinese ? "品牌蓝 · 睁眼" : "Brand blue · Awake")
        ]
        func centered(_ value: String, _ center: CGFloat, _ top: CGFloat, _ size: CGFloat,
                      _ color: NSColor, _ weight: NSFont.Weight = .regular) {
            let font = NSFont.systemFont(ofSize: size, weight: weight)
            let w = (value as NSString).size(withAttributes: [.font: font]).width
            text(value, center - w / 2, top, size, color, weight)
        }
        for (state, center, title, detail) in columns {
            centered(title, center, 103, 17, ink, .medium)
            GuardianMenuSymbol.draw(state, in: rect(center - 32, 145, 64, 64),
                                    color: state == .openLid ? GuardianMenuSymbol.openLidColor : ink)
            centered(detail, center, 228, 13, secondary)
        }
        for dark in [false, true] {
            let top: CGFloat = dark ? 390 : 294
            (dark ? NSColor(calibratedWhite: 0.12, alpha: 1) : NSColor(calibratedWhite: 0.90, alpha: 1)).setFill()
            NSBezierPath(roundedRect: rect(54, top, 792, 72), xRadius: 14, yRadius: 14).fill()
            let foreground: NSColor = dark ? .white : .black
            text(chinese ? (dark ? "深色菜单栏" : "浅色菜单栏") : (dark ? "Dark menu bar" : "Light menu bar"),
                78, top + 25, 12, foreground.withAlphaComponent(0.75))
            for (index, state) in [GuardianMenuState.off, .on, .openLid].enumerated() {
                let x = CGFloat(320 + index * 175)
                GuardianMenuSymbol.draw(state, in: rect(x, top + 27, 18, 18),
                                        color: state == .openLid ? GuardianMenuSymbol.openLidColor : foreground)
                let labels = chinese ? ["关闭", "合盖", "开盖"] : ["Off", "Closed lid", "Open lid"]
                text(labels[index], x + 32, top + 25, 12, foreground)
            }
        }
        text(chinese ? "下方以 18 pt 实际尺寸绘制，使用与应用相同的矢量代码。" : "18 pt at actual size below, rendered from the app's production vector code.",
            54, 483, 11, secondary)
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
    }
}

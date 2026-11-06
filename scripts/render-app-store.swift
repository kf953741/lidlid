import AppKit

// Compose the approved campaign illustrations with genuine, unmodified app
// captures. Marketing typography is outside the native UI; no mock purchases.
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let out = root.appendingPathComponent("docs/app-store")
let W: CGFloat = 1440, H: CGFloat = 900
let names = ["01-close-and-go", "02-carry-with-ease", "03-open-lid-free", "04-time-limits", "05-local-and-private"]
let ink = NSColor(srgbRed: 0.06, green: 0.17, blue: 0.15, alpha: 1)
let muted = NSColor(srgbRed: 0.36, green: 0.41, blue: 0.40, alpha: 1)
let blue = NSColor(srgbRed: 0.22, green: 0.40, blue: 0.79, alpha: 1)
let cream = NSColor(srgbRed: 0.985, green: 0.964, blue: 0.916, alpha: 1)
let navy = NSColor(srgbRed: 0.09, green: 0.15, blue: 0.23, alpha: 1)
let gold = NSColor(srgbRed: 0.98, green: 0.76, blue: 0.40, alpha: 1)

func rect(_ x: CGFloat, _ top: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x, y: H - top - h, width: w, height: h)
}
func fill(_ color: NSColor, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat = 0) {
    color.setFill(); NSBezierPath(roundedRect: rect(x, y, w, h), xRadius: radius, yRadius: radius).fill()
}
func text(_ s: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ size: CGFloat,
          _ color: NSColor = ink, _ weight: NSFont.Weight = .regular, serif: Bool = false) {
    let p = NSMutableParagraphStyle(); p.lineSpacing = size >= 45 ? 5 : 6; p.lineBreakMode = .byWordWrapping
    let font = serif ? (NSFont(name: s.contains(where: { $0.isASCII == false }) ? "Songti SC Bold" : "Georgia-Bold", size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)) : NSFont.systemFont(ofSize: size, weight: weight)
    let a = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: p, .kern: size >= 45 ? -1.5 : 0])
    let bounds = a.boundingRect(with: NSSize(width: w, height: 2000), options: [.usesLineFragmentOrigin, .usesFontLeading])
    precondition(bounds.height <= h + 2, "Text overflow: \(s): \(bounds.height) > \(h)")
    a.draw(with: rect(x, y, w, h), options: [.usesLineFragmentOrigin, .usesFontLeading])
}
func load(_ path: String) -> NSImage {
    guard let image = NSImage(contentsOf: root.appendingPathComponent(path)) else { fatalError("Missing \(path)") }
    return image
}
func draw(_ image: NSImage, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat) {
    image.draw(in: rect(x, y, w, w * image.size.height / image.size.width), from: .zero, operation: .sourceOver, fraction: 1)
}
func shadow(_ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let s = NSShadow(); s.shadowColor = navy.withAlphaComponent(0.15); s.shadowBlurRadius = 30; s.shadowOffset = NSSize(width: 0, height: -14); s.set()
    body(); NSGraphicsContext.restoreGraphicsState()
}
// Coordinates refer to the original native image, measured from its top edge.
// Only framing/scaling is applied; pixels inside each region are never repainted.
func native(_ cn: Bool, _ top: CGFloat, _ height: CGFloat, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat) {
    let image = load("docs/app-store/captures/\(cn ? "zh-Hans" : "en-US")/main.png")
    let source = NSRect(x: 50, y: image.size.height - top - height, width: 604, height: height)
    let dest = rect(x, y, width, width * height / 604)
    shadow { fill(NSColor(srgbRed: 0.145, green: 0.16, blue: 0.15, alpha: 1), x, y, dest.width, dest.height, 20) }
    NSGraphicsContext.saveGraphicsState(); NSBezierPath(roundedRect: dest, xRadius: 20, yRadius: 20).addClip()
    image.draw(in: dest, from: source, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}
func header(_ cn: Bool, _ page: Int, dark: Bool = false) {
    draw(load("docs/assets/app-icon.png"), 72, 48, 58)
    text(cn ? "盖盖 · LidLid" : "LidLid", 146, 64, 600, 40, 25, dark ? cream : ink, .semibold)
    if page > 0 { text(String(format: "%02d / %02d", page, names.count), 1260, 67, 110, 30, 16, dark ? cream.withAlphaComponent(0.65) : muted) }
}
func footer(_ cn: Bool, dark: Bool = false) {
    let c = dark ? cream.withAlphaComponent(0.65) : muted
    text(cn ? "开盖永久免费 · 合盖试用 7 天，之后一次购买永久解锁 · 合盖功能需免费兼容组件"
            : "Open-lid mode is free · Closed-lid: 7-day trial, then a one-time purchase · Free component required",
         74, 842, 1292, 26, 13, c)
    text(cn ? "Apple Silicon MacBook · macOS 14+ · 联网任务仍需网络连接"
            : "Apple Silicon MacBook · macOS 14+ · Online tasks still need a network connection",
         74, 870, 1292, 22, 11, c)
}
func circle(_ x: CGFloat, _ top: CGFloat, _ size: CGFloat, _ color: NSColor) {
    color.setFill(); NSBezierPath(ovalIn: rect(x, top, size, size)).fill()
}
func clockFace() {
    circle(914, 161, 432, cream)
    let cx: CGFloat = 1130, cy: CGFloat = H - 377
    for i in 0..<12 {
        let a = CGFloat(i) * .pi / 6
        let p = NSBezierPath(); p.move(to: NSPoint(x: cx + sin(a) * 177, y: cy + cos(a) * 177)); p.line(to: NSPoint(x: cx + sin(a) * 190, y: cy + cos(a) * 190)); p.lineWidth = i % 3 == 0 ? 5 : 2; navy.withAlphaComponent(i % 3 == 0 ? 1 : 0.3).setStroke(); p.stroke()
    }
    let p = NSBezierPath(); p.move(to: NSPoint(x: cx - 64, y: cy + 56)); p.line(to: NSPoint(x: cx, y: cy)); p.line(to: NSPoint(x: cx + 99, y: cy + 92)); p.lineWidth = 12; p.lineCapStyle = .round; navy.setStroke(); p.stroke()
    circle(1117, 364, 26, gold)
}
func render(_ filename: String, _ locale: String, _ body: (Bool) -> Void) throws {
    let ctx = CGContext(data: nil, width: 2880, height: 1800, bitsPerComponent: 8, bytesPerRow: 2880 * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.scaleBy(x: 2, y: 2)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.current?.imageInterpolation = .high
    fill(cream, 0, 0, W, H); body(locale == "zh-Hans")
    NSGraphicsContext.restoreGraphicsState()
    let dir = out.appendingPathComponent("\(filename.hasPrefix("review-") ? "review-screenshots" : "screenshots")/\(locale)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent(filename + ".png"))
}
for locale in ["zh-Hans", "en-US"] {
    try render(names[0], locale) { cn in
        draw(load("docs/assets/\(cn ? "zh-CN/" : "")hero-mobility.png"), 0, 0, W)
        native(cn, cn ? 174 : 177, 133, 74, 737, 410)
        text(cn ? "不插电，不接外接屏。" : "No charger. No external display.", 550, 739, 810, 43, 29, ink, .semibold)
        text(cn ? "让编译、下载和本机任务，跟你一起出发。" : "Bring your builds, downloads and local tasks along.", 550, 786, 810, 34, 20, muted)
        footer(cn)
    }
    try render(names[1], locale) { cn in
        draw(load("docs/assets/\(cn ? "zh-CN/" : "")use-case-mobility.png"), 0, 0, W)
        native(cn, cn ? 397 : 433, cn ? 135 : 146, 74, 737, 410)
        text(cn ? "任务没完，也能从容出发。" : "Work in progress. Freedom to move.", 550, 739, 810, 43, cn ? 29 : 28, ink, .semibold)
        text(cn ? "再次开盖自动结束，本次设置清清楚楚。" : "Reopening ends the session. Normal sleep returns.", 550, 786, 810, 34, 20, muted)
        footer(cn)
    }
    try render(names[2], locale) { cn in
        fill(NSColor(srgbRed: 0.91, green: 0.94, blue: 0.98, alpha: 1), 0, 0, W, H)
        circle(828, 160, 565, NSColor.white.withAlphaComponent(0.48))
        header(cn, 3)
        text(cn ? "屏幕休息，\n任务继续。" : "Let the screen rest.\nKeep work going.", 74, 183, 790, 190, cn ? 64 : 59, ink, .semibold, serif: true)
        text(cn ? "开盖不休眠，永久免费。" : "Open-lid keep-awake. Always free.", 78, 399, 760, 54, 28, blue, .semibold)
        text(cn ? "屏幕照常自动熄灭，\nMac 不因闲置而睡眠。" : "Your display can sleep.\nYour Mac stays awake while the lid is open.", 78, 462, 730, 90, 23, muted)
        native(cn, cn ? 568 : 600, cn ? 127 : 151, 78, 604, 718)
        shadow { draw(load("docs/assets/app-icon.png"), 886, 224, 455) }
        footer(cn)
    }
    try render(names[3], locale) { cn in
        fill(navy, 0, 0, W, H); header(cn, 4, dark: true)
        text(cn ? "时间你来定。" : "Your time.\nYour choice.", 74, 190, 790, 180, cn ? 78 : 68, cream, .semibold, serif: true)
        text(cn ? "30 分钟至 8 小时，\n或保持到下一次开盖。" : "30 minutes to 8 hours.\nOr until you reopen the lid.", 78, 414, 760, 103, 29, cream.withAlphaComponent(0.83))
        clockFace()
        native(cn, cn ? 397 : 433, cn ? 135 : 146, 78, 607, 740)
        text(cn ? "开盖或到时，\n以先发生者为准。" : "Ends on reopening\nor at your limit.", 920, 662, 430, 85, 27, gold, .medium)
        footer(cn, dark: true)
    }
    try render(names[4], locale) { cn in
        header(cn, 5)
        text(cn ? "你的任务，\n只属于你。" : "Your work\nstays yours.", 74, 182, 770, 191, cn ? 64 : 68, ink, .semibold, serif: true)
        let rows = cn ? [("无需账号", "打开就用，无需注册。"), ("不读取代码或对话", "盖盖只管理 Mac 的睡眠。"), ("不收集个人数据", "偏好与诊断留在本机。")]
                      : [("No account", "Open the app. Get going."), ("No reading your code or chats", "LidLid manages your Mac’s sleep."), ("No personal data collected", "Preferences and diagnostics stay local.")]
        for (i, row) in rows.enumerated() {
            let y = CGFloat(414 + i * 119)
            text(String(format: "%02d", i + 1), 78, y + 2, 50, 34, 18, blue, .semibold)
            text(row.0, 142, y, 625, 45, 27, ink, .semibold)
            text(row.1, 142, y + 48, 625, 43, 21, muted)
        }
        shadow { draw(load("docs/app-store/captures/\(locale)/options.png"), 856, 155, 484) }
        footer(cn)
    }
    // Private IAP review attachment: complete real native capture, including
    // actual StoreKit availability. This is NOT a public product-page card.
    try render("review-purchase-ui", locale) { cn in
        header(cn, 0)
        text(cn ? "实际购买界面" : "Actual purchase interface", 74, 220, 650, 140, 52, ink, .semibold)
        text(cn ? "1.6.1（构建 12）\nApp Store 模式 · 未模拟收据\n\n完整保留试用与永久版控件。\n当前商品不可用状态也如实保留。\n真实购买流程仍需验证。" : "1.6.1 (build 12)\nApp Store mode · No simulated receipts\n\nTrial and lifetime controls are unmodified.\nThe current unavailable-product state is visible.\nReal purchase validation is still pending.", 78, 401, 660, 270, 23, muted)
        let image = load("docs/app-store/captures/\(locale)/main.png")
        draw(image, 867, 44, 772 * image.size.width / image.size.height)
    }
}
// Owner contact sheet; never upload this overview to the App Store.
let overview = CGContext(data: nil, width: 1800, height: 1660, bitsPerComponent: 8, bytesPerRow: 7200,
                         space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: overview, flipped: false)
cream.setFill(); NSRect(x: 0, y: 0, width: 1800, height: 1660).fill()
for (row, locale) in ["zh-Hans", "en-US"].enumerated() {
    let label = NSAttributedString(string: locale == "zh-Hans" ? "简体中文 · 五张商店截图" : "English · Five App Store screenshots", attributes: [.font: NSFont.systemFont(ofSize: 24, weight: .semibold), .foregroundColor: ink])
    label.draw(at: NSPoint(x: 28, y: 1614 - row * 825))
    for (index, name) in names.enumerated() {
        let col = index % 3, r = index / 3
        let frame = NSRect(x: CGFloat(26 + col * 593), y: CGFloat(1230 - row * 825 - r * 375), width: 570, height: 356.25)
        load("docs/app-store/screenshots/\(locale)/\(name).png").draw(in: frame)
    }
}
NSGraphicsContext.restoreGraphicsState()
try NSBitmapImageRep(cgImage: overview.makeImage()!).representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("screenshots-overview.png"))
print("Rendered five 2880 × 1800 opaque RGB screenshots per locale, plus private IAP review attachments.")

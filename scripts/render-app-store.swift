import AppKit

// Original product-page layouts around unmodified native app captures.
// No synthetic UI, lid-event evidence, task results, or App Store badges.
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let out = root.appendingPathComponent("docs/app-store")
let W: CGFloat = 1440, H: CGFloat = 900
let ink = NSColor(srgbRed: 0.075, green: 0.20, blue: 0.17, alpha: 1)
let accent = NSColor(srgbRed: 0.16, green: 0.40, blue: 0.33, alpha: 1)
let muted = NSColor(srgbRed: 0.40, green: 0.45, blue: 0.42, alpha: 1)
let cream = NSColor(srgbRed: 0.967, green: 0.960, blue: 0.938, alpha: 1)
let rule = NSColor(srgbRed: 0.85, green: 0.86, blue: 0.82, alpha: 1)

func box(_ x: CGFloat, _ top: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x, y: H - top - h, width: w, height: h)
}

func text(_ s: String, _ x: CGFloat, _ top: CGFloat, _ width: CGFloat, _ height: CGFloat,
          _ size: CGFloat, _ color: NSColor = ink, _ weight: NSFont.Weight = .regular) {
    let p = NSMutableParagraphStyle()
    p.lineSpacing = size >= 45 ? 7 : 6
    p.lineBreakMode = .byWordWrapping
    let a = NSAttributedString(string: s, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color,
        .paragraphStyle: p, .kern: size >= 45 ? -1.3 : 0
    ])
    let bounds = a.boundingRect(with: NSSize(width: width, height: 2000), options: [.usesLineFragmentOrigin, .usesFontLeading])
    precondition(bounds.height <= height + 2, "Text overflow: \(s), \(bounds.height) > \(height)")
    a.draw(with: box(x, top, width, height), options: [.usesLineFragmentOrigin, .usesFontLeading])
}

func load(_ relative: String) -> NSImage {
    guard let image = NSImage(contentsOf: root.appendingPathComponent(relative)) else { fatalError("Missing \(relative)") }
    return image
}

func draw(_ image: NSImage, _ x: CGFloat, _ top: CGFloat, _ width: CGFloat) {
    let height = width * image.size.height / image.size.width
    image.draw(in: box(x, top, width, height), from: .zero, operation: .sourceOver, fraction: 1)
}

func panel(_ x: CGFloat, _ top: CGFloat, _ width: CGFloat, _ height: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = ink.withAlphaComponent(0.07)
    shadow.shadowBlurRadius = 28; shadow.shadowOffset = NSSize(width: 0, height: -9); shadow.set()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: box(x, top, width, height), xRadius: 28, yRadius: 28).fill()
    NSGraphicsContext.restoreGraphicsState()
}

func pill(_ value: String, _ x: CGFloat, _ top: CGFloat, _ width: CGFloat) {
    accent.withAlphaComponent(0.08).setFill()
    NSBezierPath(roundedRect: box(x, top, width, 43), xRadius: 21.5, yRadius: 21.5).fill()
    text(value, x + 20, top + 9, width - 34, 30, 17, accent, .medium)
}

func footer(_ chinese: Bool) {
    rule.setStroke(); let line = NSBezierPath()
    line.move(to: NSPoint(x: 88, y: H - 828)); line.line(to: NSPoint(x: 1352, y: H - 828)); line.lineWidth = 0.7; line.stroke()
    text("Apple Silicon MacBook · macOS 14+", 88, 849, 450, 28, 14, muted)
    text(chinese ? "联网任务仍需网络连接。" : "Online work still needs a network connection.",
         625, 849, 727, 30, 13, muted)
}

func header(_ chinese: Bool, _ page: Int) {
    draw(load("docs/assets/app-icon.png"), 86, 57, 52)
    text(chinese ? "盖盖 · LidLid" : "LidLid", 153, 70, 450, 42, 25, ink, .semibold)
    text(String(format: "%02d / 04", page), 1266, 75, 100, 27, 15, muted, .medium)
}

func render(_ locale: String, _ page: Int, _ body: (Bool) -> Void) throws {
    let context = CGContext(data: nil, width: 2880, height: 1800, bitsPerComponent: 8,
                            bytesPerRow: 2880 * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.scaleBy(x: 2, y: 2)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current?.imageInterpolation = .high
    cream.setFill(); box(0, 0, W, H).fill()
    header(locale == "zh-Hans", page)
    body(locale == "zh-Hans")
    footer(locale == "zh-Hans")
    NSGraphicsContext.restoreGraphicsState()
    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    let names = ["01-close-and-go", "02-one-session", "03-time-limits", "04-local-and-private"]
    let dir = out.appendingPathComponent("screenshots/\(locale)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try rep.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent(names[page - 1] + ".png"))
}

for locale in ["zh-Hans", "en-US"] {
    func shot(_ state: String) -> NSImage { load("docs/app-store/captures/\(locale)/\(state).png") }
    try render(locale, 1) { cn in
        text(cn ? "任务还在跑，\n你已经要走了。" : "Close your Mac.\nKeep work moving.", 88, 207, 655, 185, cn ? 61 : 56, ink, .medium)
        text(cn ? "不用托着一台开盖的电脑。\n打开盖盖，换个地方，任务继续。" : "Stop balancing an open laptop.\nSwitch on LidLid and move to your next spot.", 92, 421, 590, 100, 23, muted)
        pill(cn ? "无需插电" : "Works on battery", 90, 569, cn ? 133 : 195)
        pill(cn ? "无需外接屏" : "No external display", cn ? 239 : 300, 569, cn ? 153 : 218)
        text(cn ? "编译、下载、渲染、AI 编程任务。" : "Builds. Downloads. Renders. Coding tasks.", 92, 688, 620, 40, 19, accent)
        panel(778, 207, 566, 523)
        draw(shot("on"), 798, 241, 526)
        text(cn ? "菜单栏里，一个清楚的开关。" : "One clear switch in your menu bar.", 807, 689, 520, 35, 17, muted)
    }
    try render(locale, 2) { cn in
        text(cn ? "这次合盖保持运行。\n开盖后，自动结束。" : "On when you need it.\nOff when you reopen.", 88, 157, 1230, 150, cn ? 53 : 54, ink, .medium)
        text(cn ? "只管这一次。下次需要时，再开启。" : "A session for this lid close. Turn it on again when you need it.", 92, 310, 1240, 42, 22, muted)
        panel(107, 386, 552, 425); panel(781, 386, 552, 425)
        draw(shot("on"), 143, 396, 480); draw(shot("off"), 817, 396, 480)
        accent.setStroke(); let a = NSBezierPath(); a.lineWidth = 2
        a.move(to: NSPoint(x: 691, y: H - 589)); a.line(to: NSPoint(x: 747, y: H - 589))
        a.move(to: NSPoint(x: 737, y: H - 580)); a.line(to: NSPoint(x: 747, y: H - 589)); a.line(to: NSPoint(x: 737, y: H - 598)); a.stroke()
    }
    try render(locale, 3) { cn in
        text(cn ? "设个时限，\n到点就结束。" : "Set a limit.\nLet LidLid end it.", 88, 204, 660, 180, cn ? 61 : 56, ink, .medium)
        text(cn ? "30 分钟至 8 小时，\n也可以保持到再次开盖。" : "From 30 minutes to 8 hours.\nOr keep going until you reopen the lid.", 92, 417, 610, 95, 23, muted)
        pill(cn ? "30 分钟" : "30 minutes", 90, 551, 153)
        pill(cn ? "1 小时" : "1 hour", 258, 551, 128)
        pill(cn ? "8 小时" : "8 hours", 401, 551, 142)
        text(cn ? "开盖或到时，以先发生者为准。" : "Ends on reopening or at your time limit,\nwhichever comes first.", 92, 672, 620, 72, 20, accent)
        panel(778, 207, 566, 523)
        draw(shot("timed"), 798, 241, 526)
        text(cn ? "开启后，直接显示最晚结束时间。" : "See when your active session ends.", 807, 689, 520, 35, 17, muted)
    }
    try render(locale, 4) { cn in
        text(cn ? "无需账号。\n偏好留在本机。" : "No account.\nNo tracking.", 88, 190, 660, 185, cn ? 61 : 61, ink, .medium)
        let rows = cn ? [("不读取代码或对话", "盖盖管理睡眠，不接管你的任务。"), ("本机偏好与诊断", "不自动上传给开发者。"), ("结束条件看得见", "电池供电时到 10%，或系统报告高温时结束。")]
                      : [("Your work is yours", "No reading your code or conversations."), ("Local preferences and diagnostics", "No automatic uploads to the developer."), ("Clear stop conditions", "10% on battery, or serious thermal pressure.")]
        for (i, row) in rows.enumerated() {
            let y = CGFloat(419 + i * 112)
            accent.setFill(); NSBezierPath(ovalIn: box(93, y + 10, 7, 7)).fill()
            text(row.0, 118, y, 595, 42, 22, ink, .medium)
            text(row.1, 118, y + 39, 595, 44, 19, muted)
        }
        panel(806, 149, 538, 647)
        draw(shot("options"), 825, 166, 500)
    }
}

// Small overview for the owner. Upload the full PNGs, never this overview.
let overview = CGContext(data: nil, width: 1600, height: 640, bitsPerComponent: 8,
                         bytesPerRow: 1600 * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                         bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: overview, flipped: false)
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 1600, height: 640).fill()
for (row, locale) in ["zh-Hans", "en-US"].enumerated() {
    let label = NSAttributedString(string: locale == "zh-Hans" ? "中文 · 2880 × 1800" : "English · 2880 × 1800", attributes: [.font: NSFont.systemFont(ofSize: 24, weight: .semibold), .foregroundColor: ink])
    label.draw(at: NSPoint(x: 30, y: 600 - row * 305))
    for (col, name) in ["01-close-and-go", "02-one-session", "03-time-limits", "04-local-and-private"].enumerated() {
        let im = load("docs/app-store/screenshots/\(locale)/\(name).png")
        im.draw(in: NSRect(x: 28 + col * 397, y: 345 - row * 305, width: 376, height: 235))
    }
}
NSGraphicsContext.restoreGraphicsState()
try NSBitmapImageRep(cgImage: overview.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: out.appendingPathComponent("screenshots-overview.png"))
print("Rendered four 2880 × 1800 RGB screenshots in each language.")

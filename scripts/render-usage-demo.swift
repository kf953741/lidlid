import AppKit

// Original captions and layout around unmodified native screenshots.
// The walking scenes reuse the project's clearly illustrated campaign artwork.
let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fatalError("Usage: swift scripts/render-usage-demo.swift REPO_ROOT OUTPUT_DIRECTORY")
}
let root = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])
let width = 1280, height = 720
let ink = NSColor(calibratedRed: 0.07, green: 0.17, blue: 0.15, alpha: 1)
let secondary = NSColor(calibratedRed: 0.39, green: 0.43, blue: 0.41, alpha: 1)
let accent = NSColor(calibratedRed: 0.16, green: 0.43, blue: 0.35, alpha: 1)

func rect(_ x: CGFloat, _ top: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x, y: CGFloat(height) - top - h, width: w, height: h)
}

func text(_ value: String, x: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat,
          size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 6
    paragraph.lineBreakMode = .byWordWrapping
    let value = NSAttributedString(string: value, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color, .paragraphStyle: paragraph,
        .kern: size >= 48 ? -1.2 : 0,
    ])
    let bounds = value.boundingRect(with: NSSize(width: width, height: 2000), options: [.usesLineFragmentOrigin, .usesFontLeading])
    precondition(bounds.height <= height + 1, "Caption overflows its frame")
    value.draw(with: rect(x, top, width, height), options: [.usesLineFragmentOrigin, .usesFontLeading])
}

func image(_ relative: String) -> NSImage {
    guard let image = NSImage(contentsOf: root.appendingPathComponent(relative)) else {
        fatalError("Missing image: \(relative)")
    }
    return image
}

func drawImage(_ image: NSImage, in target: NSRect, cover: Bool = false) {
    let ratio = cover ? max(target.width / image.size.width, target.height / image.size.height)
                      : min(target.width / image.size.width, target.height / image.size.height)
    let size = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
    let destination = NSRect(x: target.midX - size.width / 2, y: target.midY - size.height / 2,
                             width: size.width, height: size.height)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: target, xRadius: 26, yRadius: 26).addClip()
    image.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

func walkingImage(_ source: NSImage, right: Bool) -> NSImage {
    var proposed = NSRect(origin: .zero, size: source.size)
    let cg = source.cgImage(forProposedRect: &proposed, context: nil, hints: nil)!
    let half = cg.width / 2
    let cropped = cg.cropping(to: CGRect(x: (right ? half : 0) + 30, y: 132,
                                         width: half - 60, height: cg.height - 144))!
    return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
}

for language in ["zh-CN", "en"] {
    let chinese = language == "zh-CN"
    let directory = output.appendingPathComponent(language)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let artwork = image(chinese ? "docs/assets/zh-CN/use-case-mobility.png" : "docs/assets/use-case-mobility.png")
    let before = walkingImage(artwork, right: false)
    let after = walkingImage(artwork, right: true)
    let screenshots = ["off", "on", "reopened"].map { image("docs/assets/\(language)/demo-\($0).jpg") }
    let titles = chinese ? [
        "任务还在跑，\n你已经要走了。", "点开菜单栏的\n猫头鹰。", "打开开关，\n这次合盖不休眠。",
        "合上电脑，\n从容出发。", "再次开盖，\n本次自动结束。", "合上盖子，\n带着任务走。",
    ] : [
        "Task still running?\nTime to head out.", "Open the owl\nin your menu bar.", "Switch it on.\nClose the lid.",
        "Carry your Mac.\nLet the work continue.", "Reopen the lid.\nThe session ends.", "Close the lid.\nCarry on.",
    ]
    let details = chinese ? [
        "Codex、Claude Code、编译或下载。\n不用再托着开盖电脑走。",
        "一个开关，控制本次合盖。\n默认关闭，需要时再开启。",
        "看到「已开启」，就可以合盖。\n无需外接显示器。",
        "本机任务继续运行，\n你也可以换个地方。",
        "开盖后自动回到「已关闭」。\n下次需要时，再开启一次。",
        "免费开源 · M 系列 MacBook\nmacOS 14+ · 中文 / English",
    ] : [
        "Codex, Claude Code, builds or downloads.\nStop balancing an open laptop as you walk.",
        "One switch for this lid close.\nOff by default. On when you need it.",
        "Wait until LidLid shows On.\nNo external monitor needed.",
        "Keep local work running\nwhile you move somewhere else.",
        "LidLid returns to Off automatically.\nTurn it on again when you need it.",
        "Free & open source · Apple Silicon\nmacOS 14+ · English / 简体中文",
    ]
    let labels = chinese ? ["任务没结束，人先出发", "01 / 打开盖盖", "02 / 开启本次", "03 / 合盖带走", "04 / 开盖结束", "盖盖 · LidLid"]
                         : ["WORK IN PROGRESS. LIFE IN MOTION.", "01 / OPEN LIDLID", "02 / SWITCH ON", "03 / CLOSE AND GO", "04 / REOPEN", "LIDLID"]
    for index in 0..<6 {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image("docs/assets/app-icon.png").draw(in: rect(72, 45, 42, 42))
        text(chinese ? "盖盖 · LidLid" : "LidLid", x: 126, top: 53, width: 360, height: 36,
             size: 22, color: ink, weight: .semibold)
        text(chinese ? "20 秒，学会盖盖" : "20 seconds to get started", x: 926, top: 57,
             width: 290, height: 30, size: 17, color: secondary)
        text(labels[index], x: 74, top: 178, width: 500, height: 40, size: 17, color: accent, weight: .medium)
        text(titles[index], x: 70, top: 230, width: 525, height: 188,
             size: chinese ? 52 : 48, color: ink, weight: .medium)
        text(details[index], x: 74, top: 435, width: 520, height: 90, size: 21, color: secondary)
        if index == 5 {
            accent.setFill()
            NSBezierPath(roundedRect: rect(74, 545, 220, 54), xRadius: 27, yRadius: 27).fill()
            text(chinese ? "下载 DMG  ↗" : "Download DMG  ↗", x: 101, top: 560, width: 190,
                 height: 34, size: 19, color: .white, weight: .medium)
            text("github.com/kf953741/lidlid", x: 74, top: 625, width: 490, height: 30, size: 18, color: ink)
        } else {
            for dot in 0..<5 {
                (dot == index ? accent : NSColor(calibratedWhite: 0.9, alpha: 1)).setFill()
                NSBezierPath(roundedRect: rect(74 + CGFloat(dot) * 47, 584, 34, 4), xRadius: 2, yRadius: 2).fill()
            }
            text(chinese ? "合上盖子，带着任务走。" : "Close the lid. Carry on.", x: 74, top: 636,
                 width: 510, height: 32, size: 17, color: secondary)
        }
        if index == 0 || index == 3 || index == 5 {
            drawImage(index == 0 ? before : after, in: rect(644, 120, 564, 548), cover: true)
        } else {
            drawImage(screenshots[index == 1 ? 0 : index == 2 ? 1 : 2], in: rect(624, 140, 584, 500))
        }
        NSGraphicsContext.restoreGraphicsState()
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("scene-\(index).png"))
    }
}
print("Rendered six scenes per language from native captures and existing illustrations.")

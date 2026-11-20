import AppKit

/// Original vector artwork. Designed on a 24-unit grid for an 18 pt status item.
/// Solid fill signals a closed-lid session. Blue ink and a dot signal open-lid
/// keep-awake. Both marks are visible when both modes are enabled.
enum GuardianMenuState: String, CaseIterable {
    case off, on, openLid, both

    init(closedLidEnabled: Bool, openLidEnabled: Bool) {
        switch (closedLidEnabled, openLidEnabled) {
        case (false, false): self = .off
        case (true, false): self = .on
        case (false, true): self = .openLid
        case (true, true): self = .both
        }
    }

    var closedLidEnabled: Bool { self == .on || self == .both }
    var openLidEnabled: Bool { self == .openLid || self == .both }
}

enum GuardianMenuSymbol {
    static let openLidColor = NSColor(srgbRed: 0.26, green: 0.50, blue: 0.94, alpha: 1)
    static func image(for state: GuardianMenuState, size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            draw(state, in: rect, color: state.openLidEnabled ? openLidColor : .black)
            return true
        }
        image.isTemplate = !state.openLidEnabled
        image.accessibilityDescription = label(state)
        return image
    }

    static func label(_ state: GuardianMenuState) -> String {
        switch state {
        case .off: return "盖盖：已关闭"
        case .on: return "盖盖：已开启，仅本次合盖不休眠"
        case .openLid: return "盖盖：开盖不休眠已开启"
        case .both: return "盖盖：合盖与开盖不休眠已开启"
        }
    }

    static func draw(_ state: GuardianMenuState, in rect: NSRect, color: NSColor) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform = AffineTransform(
            m11: rect.width / 24, m12: 0,
            m21: 0, m22: -rect.height / 24,
            tX: rect.minX, tY: rect.maxY
        )
        (transform as NSAffineTransform).concat()

        // Broad soft body and two small paws echo the approved blue guardian.
        let head = NSBezierPath()
        head.move(to: NSPoint(x: 5.2, y: 8.2))
        head.curve(to: NSPoint(x: 5.4, y: 4.4), controlPoint1: NSPoint(x: 3.2, y: 7.8), controlPoint2: NSPoint(x: 3.2, y: 4.9))
        head.curve(to: NSPoint(x: 8.5, y: 6.8), controlPoint1: NSPoint(x: 7.3, y: 3.8), controlPoint2: NSPoint(x: 8.5, y: 5.4))
        head.curve(to: NSPoint(x: 15.7, y: 7.3), controlPoint1: NSPoint(x: 10.4, y: 6.1), controlPoint2: NSPoint(x: 13.4, y: 6.2))
        head.curve(to: NSPoint(x: 18.3, y: 4.8), controlPoint1: NSPoint(x: 15.3, y: 5.5), controlPoint2: NSPoint(x: 16.7, y: 4.2))
        head.curve(to: NSPoint(x: 19.1, y: 9.1), controlPoint1: NSPoint(x: 20.3, y: 5.4), controlPoint2: NSPoint(x: 20.5, y: 7.9))
        head.curve(to: NSPoint(x: 21.7, y: 16.6), controlPoint1: NSPoint(x: 20.6, y: 11), controlPoint2: NSPoint(x: 22, y: 13.3))
        head.curve(to: NSPoint(x: 16.5, y: 20.8), controlPoint1: NSPoint(x: 21.4, y: 19.3), controlPoint2: NSPoint(x: 19.3, y: 20.8))
        head.line(to: NSPoint(x: 7.3, y: 20.8))
        head.curve(to: NSPoint(x: 2.3, y: 16.1), controlPoint1: NSPoint(x: 3.9, y: 20.8), controlPoint2: NSPoint(x: 2.1, y: 19.1))
        head.curve(to: NSPoint(x: 5.2, y: 8.2), controlPoint1: NSPoint(x: 2.5, y: 12.8), controlPoint2: NSPoint(x: 3.4, y: 10.1))
        head.close()
        color.setFill(); color.setStroke()

        let eyes = NSBezierPath(ovalIn: NSRect(x: 6.2, y: 10.9, width: 3.8, height: 4.8))
        eyes.append(NSBezierPath(ovalIn: NSRect(x: 14, y: 10.2, width: 3.8, height: 4.8)))
        if state.closedLidEnabled {
            head.append(eyes)
            head.windingRule = .evenOdd
            head.fill()
        } else {
            head.lineWidth = 1.7
            head.lineJoinStyle = .round
            head.stroke()
        }

        if state == .off {
            for x: CGFloat in [8.1, 15.9] {
                let lid = NSBezierPath()
                lid.move(to: NSPoint(x: x - 2.2, y: 11.8))
                lid.curve(to: NSPoint(x: x + 2.2, y: 11.8),
                    controlPoint1: NSPoint(x: x - 1, y: 13.8),
                    controlPoint2: NSPoint(x: x + 1, y: 13.8))
                lid.lineWidth = 1.8; lid.lineCapStyle = .round; lid.stroke()
            }
        } else if !state.closedLidEnabled {
            eyes.fill()
        }

        if state.openLidEnabled {
            NSBezierPath(ovalIn: NSRect(x: 20.2, y: 0.65, width: 3.8, height: 3.8)).fill()
        }
    }
}

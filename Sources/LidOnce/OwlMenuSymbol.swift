import AppKit

/// Original vector artwork. Designed on a 24-unit grid for an 18 pt status item.
/// Use as a template image so macOS supplies the menu-bar foreground color.
/// The user sees only off/on. Both internal armed and lid-closed phases map to on.
/// Reopening the lid consumes the one-shot session and returns the icon to off.
enum OwlMenuState: String, CaseIterable {
    case off, on
}

enum OwlMenuSymbol {
    static func image(for state: OwlMenuState, size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            draw(state, in: rect, color: .black)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = label(state)
        return image
    }

    static func label(_ state: OwlMenuState) -> String {
        switch state {
        case .off: return "盖盖：已关闭"
        case .on: return "盖盖：已开启，仅本次合盖不休眠"
        }
    }

    static func draw(_ state: OwlMenuState, in rect: NSRect, color: NSColor) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform = AffineTransform(
            m11: rect.width / 24, m12: 0,
            m21: 0, m22: -rect.height / 24,
            tX: rect.minX, tY: rect.maxY
        )
        (transform as NSAffineTransform).concat()

        let head = NSBezierPath()
        head.move(to: NSPoint(x: 3, y: 2.7))
        head.curve(to: NSPoint(x: 7.1, y: 5.8), controlPoint1: NSPoint(x: 4, y: 4.2), controlPoint2: NSPoint(x: 5.6, y: 5.2))
        head.curve(to: NSPoint(x: 16.9, y: 5.8), controlPoint1: NSPoint(x: 10, y: 4.4), controlPoint2: NSPoint(x: 14, y: 4.4))
        head.curve(to: NSPoint(x: 21, y: 2.7), controlPoint1: NSPoint(x: 18.4, y: 5.2), controlPoint2: NSPoint(x: 20, y: 4.2))
        head.curve(to: NSPoint(x: 20.5, y: 9.4), controlPoint1: NSPoint(x: 21.8, y: 5.2), controlPoint2: NSPoint(x: 21.1, y: 7.5))
        head.curve(to: NSPoint(x: 17.8, y: 18.9), controlPoint1: NSPoint(x: 22, y: 13), controlPoint2: NSPoint(x: 20.7, y: 16.7))
        head.curve(to: NSPoint(x: 12, y: 21.6), controlPoint1: NSPoint(x: 16, y: 20.2), controlPoint2: NSPoint(x: 14, y: 21))
        head.curve(to: NSPoint(x: 6.2, y: 18.9), controlPoint1: NSPoint(x: 10, y: 21), controlPoint2: NSPoint(x: 8, y: 20.2))
        head.curve(to: NSPoint(x: 3.5, y: 9.4), controlPoint1: NSPoint(x: 3.3, y: 16.7), controlPoint2: NSPoint(x: 2, y: 13))
        head.curve(to: NSPoint(x: 3, y: 2.7), controlPoint1: NSPoint(x: 2.9, y: 7.5), controlPoint2: NSPoint(x: 2.2, y: 5.2))
        head.close()

        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: 10.9, y: 16.3))
        beak.line(to: NSPoint(x: 13.1, y: 16.3))
        beak.line(to: NSPoint(x: 12, y: 18.6))
        beak.close()
        color.setFill(); color.setStroke()
        if state == .off {
            // The resting state has little ink and unmistakably closed eyelids.
            head.lineWidth = 1.7; head.lineJoinStyle = .round; head.stroke()
            for x: CGFloat in [7.7, 16.3] {
                let lid = NSBezierPath()
                lid.move(to: NSPoint(x: x - 2.2, y: 11.8))
                lid.curve(to: NSPoint(x: x + 2.2, y: 11.8),
                    controlPoint1: NSPoint(x: x - 1, y: 13.8),
                    controlPoint2: NSPoint(x: x + 1, y: 13.8))
                lid.lineWidth = 1.8; lid.lineCapStyle = .round; lid.stroke()
            }
            beak.fill()
        } else {
            // Large transparent eye sockets and a solid silhouette stay distinct
            // from off at 18 pt, including with white template ink on a dark bar.
            for x: CGFloat in [7.7, 16.3] {
                head.append(NSBezierPath(ovalIn: NSRect(x: x - 3.7, y: 7.4, width: 7.4, height: 8)))
            }
            head.append(beak)
            head.windingRule = .evenOdd
            head.fill()
            for x: CGFloat in [7.7, 16.3] {
                NSBezierPath(ovalIn: NSRect(x: x - 1.9, y: 9.1, width: 3.8, height: 4.6)).fill()
            }
        }
    }
}

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
        case .off: return "合留：已关闭"
        case .on: return "合留：已开启，仅本次合盖不休眠"
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

        // Transparent heart-shaped facial mask. It works on both light and dark bars.
        let face = NSBezierPath()
        face.move(to: NSPoint(x: 12, y: 10.3))
        face.curve(to: NSPoint(x: 4.8, y: 11.5), controlPoint1: NSPoint(x: 8.9, y: 6.2), controlPoint2: NSPoint(x: 5.2, y: 7.5))
        face.curve(to: NSPoint(x: 12, y: 18.8), controlPoint1: NSPoint(x: 4, y: 16.2), controlPoint2: NSPoint(x: 8.4, y: 17.2))
        face.curve(to: NSPoint(x: 19.2, y: 11.5), controlPoint1: NSPoint(x: 15.6, y: 17.2), controlPoint2: NSPoint(x: 20, y: 16.2))
        face.curve(to: NSPoint(x: 12, y: 10.3), controlPoint1: NSPoint(x: 18.8, y: 7.5), controlPoint2: NSPoint(x: 15.1, y: 6.2))
        face.close()
        color.setFill(); color.setStroke()
        if state == .off {
            head.lineWidth = 2; head.lineJoinStyle = .round; head.stroke()
        } else {
            head.append(face)
            head.windingRule = .evenOdd
            head.fill()
        }

        func eye(x: CGFloat, open: Bool) {
            if open {
                NSBezierPath(ovalIn: NSRect(x: x - 1.2, y: 11.3, width: 2.4, height: 3.1)).fill()
            } else {
                let lid = NSBezierPath()
                lid.move(to: NSPoint(x: x - 1.8, y: 12.3))
                lid.curve(to: NSPoint(x: x + 1.8, y: 12.3), controlPoint1: NSPoint(x: x - 0.8, y: 13.3), controlPoint2: NSPoint(x: x + 0.8, y: 13.3))
                lid.lineWidth = 1.65; lid.lineCapStyle = .round; lid.stroke()
            }
        }
        eye(x: 8.1, open: state == .on)
        eye(x: 15.9, open: state == .on)
        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: 11.1, y: 15.2))
        beak.line(to: NSPoint(x: 12.9, y: 15.2))
        beak.line(to: NSPoint(x: 12, y: 17.1)); beak.close(); beak.fill()
    }
}

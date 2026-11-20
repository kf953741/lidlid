import AppKit
import SwiftUI

enum PanelStyle {
    static let background = Color(nsColor: NSColor(name: "LidLidPanel") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.125, green: 0.137, blue: 0.153, alpha: 1)
            : NSColor(srgbRed: 0.980, green: 0.978, blue: 0.967, alpha: 1)
    })
    static let accent = Color(nsColor: NSColor(name: "LidLidBlueInk") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.55, green: 0.69, blue: 0.99, alpha: 1)
            : NSColor(srgbRed: 0.15, green: 0.34, blue: 0.70, alpha: 1)
    })
    static let controlTint = Color(nsColor: NSColor(srgbRed: 0.19, green: 0.38, blue: 0.76, alpha: 1))
    static let modeInset: CGFloat = 12
}

import AppKit
import SwiftUI

/// Flagship hybrid visual system:
/// - Dark mode: Liquid Glass (high-translucency frosted glass, 1px specular rim, glacier cobalt glow).
/// - Light mode: Warm Ceramic (bone porcelain surface, pure white elevated cards, inverted Klein Cobalt hero).
enum PanelStyle {
    static let background = Color(nsColor: NSColor(name: "LidLidPanel") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.082, green: 0.102, blue: 0.145, alpha: 1)
            : NSColor(srgbRed: 0.969, green: 0.961, blue: 0.941, alpha: 1)
    })
    static let backdropTint = Color(nsColor: NSColor(name: "LidLidBackdropTint") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.070, green: 0.095, blue: 0.155, alpha: 0.44)
            : NSColor(srgbRed: 0.969, green: 0.961, blue: 0.941, alpha: 0.84)
    })
    static let accent = Color(nsColor: NSColor(name: "LidLidBlueInk") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.52, green: 0.72, blue: 1.0, alpha: 1)
            : NSColor(srgbRed: 0.118, green: 0.302, blue: 0.847, alpha: 1)
    })
    static let controlTint = Color(nsColor: NSColor(name: "LidLidControlTint") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.31, green: 0.56, blue: 1.0, alpha: 1)
            : NSColor(srgbRed: 0.118, green: 0.302, blue: 0.847, alpha: 1)
    })
    /// Higher-contrast cobalt fill (~6.0:1 dark / ~7.6:1 light against white text) for primary buttons.
    static let prominentButtonFill = Color(nsColor: NSColor(name: "LidLidButtonFill") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.145, green: 0.388, blue: 0.898, alpha: 1)
            : NSColor(srgbRed: 0.118, green: 0.302, blue: 0.847, alpha: 1)
    })
    static let amberAccent = Color(nsColor: NSColor(name: "LidLidAmberInk") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.99, green: 0.78, blue: 0.30, alpha: 1)
            : NSColor(srgbRed: 0.76, green: 0.41, blue: 0.04, alpha: 1)
    })
    static let amberFill = Color(nsColor: NSColor(name: "LidLidAmberFill") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.96, green: 0.62, blue: 0.04, alpha: 1)
            : NSColor(srgbRed: 0.85, green: 0.47, blue: 0.02, alpha: 1)
    })
    static let cardBackground = Color(nsColor: NSColor(name: "LidLidCard") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.075)
            : NSColor(white: 1.0, alpha: 0.94)
    })
    static let activeCardBackground = Color(nsColor: NSColor(name: "LidLidActiveCard") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.23, green: 0.51, blue: 0.96, alpha: 0.36)
            : NSColor(srgbRed: 0.118, green: 0.302, blue: 0.847, alpha: 1)
    })
    static let activeCardBorder = Color(nsColor: NSColor(name: "LidLidActiveBorder") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.58, green: 0.77, blue: 0.99, alpha: 0.48)
            : NSColor(white: 1.0, alpha: 0.24)
    })
    static let openTileActiveBackground = Color(nsColor: NSColor(name: "LidLidOpenTileBG") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.31, green: 0.55, blue: 1.0, alpha: 0.28)
            : NSColor(srgbRed: 0.93, green: 0.955, blue: 1.0, alpha: 1)
    })
    static let openTileActiveBorder = Color(nsColor: NSColor(name: "LidLidOpenTileBorder") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.58, green: 0.77, blue: 0.99, alpha: 0.48)
            : NSColor(srgbRed: 0.118, green: 0.302, blue: 0.847, alpha: 0.72)
    })
    static let displayTileActiveBackground = Color(nsColor: NSColor(name: "LidLidDisplayTileBG") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.96, green: 0.65, blue: 0.08, alpha: 0.24)
            : NSColor(srgbRed: 0.996, green: 0.965, blue: 0.902, alpha: 1)
    })
    static let displayTileActiveBorder = Color(nsColor: NSColor(name: "LidLidDisplayTileBorder") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.99, green: 0.82, blue: 0.30, alpha: 0.46)
            : NSColor(srgbRed: 0.85, green: 0.47, blue: 0.02, alpha: 0.70)
    })
    static let subtleBorder = Color(nsColor: NSColor(name: "LidLidSubtleBorder") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.14)
            : NSColor(srgbRed: 0.08, green: 0.10, blue: 0.14, alpha: 0.075)
    })
    static let pillBackground = Color(nsColor: NSColor(name: "LidLidPill") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.52, green: 0.72, blue: 1.0, alpha: 0.18)
            : NSColor(srgbRed: 0.118, green: 0.302, blue: 0.847, alpha: 0.09)
    })
    static let chromePill = Color(nsColor: NSColor(name: "LidLidChromePill") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.10)
            : NSColor(srgbRed: 0.08, green: 0.10, blue: 0.14, alpha: 0.06)
    })
    static let modeInset: CGFloat = 14
    static let cardCorner: CGFloat = 15

    static func heroActiveGradient(dark: Bool) -> LinearGradient {
        if dark {
            return LinearGradient(
                colors: [
                    Color(nsColor: NSColor(srgbRed: 0.23, green: 0.51, blue: 0.96, alpha: 0.48)),
                    Color(nsColor: NSColor(srgbRed: 0.22, green: 0.74, blue: 0.97, alpha: 0.24))
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(nsColor: NSColor(srgbRed: 0.135, green: 0.335, blue: 0.885, alpha: 1)),
                Color(nsColor: NSColor(srgbRed: 0.088, green: 0.230, blue: 0.675, alpha: 1))
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    static func specularRim(dark: Bool, active: Bool = false) -> LinearGradient {
        if active {
            return LinearGradient(
                colors: dark
                    ? [Color(nsColor: NSColor(srgbRed: 0.65, green: 0.82, blue: 1.0, alpha: 0.58)),
                       Color(nsColor: NSColor(srgbRed: 0.52, green: 0.75, blue: 1.0, alpha: 0.18))]
                    : [Color.white.opacity(0.32), Color.white.opacity(0.06)],
                startPoint: .top, endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: dark
                ? [Color.white.opacity(0.24), Color.white.opacity(0.07)]
                : [Color.white.opacity(0.95), Color.black.opacity(0.065)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

struct PanelBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    var material: NSVisualEffectView.Material = .popover

    var body: some View {
        ZStack {
            VisualEffectBackdrop(material: material)
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(nsColor: NSColor(srgbRed: 0.10, green: 0.14, blue: 0.24, alpha: 0.40)),
                        Color(nsColor: NSColor(srgbRed: 0.05, green: 0.07, blue: 0.13, alpha: 0.56))
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            } else {
                PanelStyle.backdropTint
            }
        }
        .ignoresSafeArea()
    }
}

private struct VisualEffectBackdrop: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

/// Gentle pulsing indicator dot used when closed-lid keep-awake is armed.
struct PulsingStatusDot: View {
    let active: Bool
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            if active && !reduceMotion {
                Circle()
                    .fill(color.opacity(pulse ? 0.12 : 0.42))
                    .frame(width: pulse ? 13 : 8, height: pulse ? 13 : 8)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)
            }
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
        }
        .frame(width: 12, height: 12)
        .onAppear { pulse = active }
        .onChange(of: active) { _, nowActive in pulse = nowActive }
    }
}

/// Branded cobalt toggle switch with optional frosted white-on-blue style
/// when placed inside an inverted Klein Cobalt hero card.
struct BrandSwitchToggleStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onInvertedHero: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let trackFill: Color = {
            if onInvertedHero {
                return configuration.isOn ? Color.white.opacity(0.32) : Color.white.opacity(0.18)
            }
            return configuration.isOn ? PanelStyle.controlTint : Color.primary.opacity(0.16)
        }()
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(trackFill)
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                onInvertedHero ? Color.white.opacity(0.28)
                                    : Color.primary.opacity(configuration.isOn ? 0 : 0.08),
                                lineWidth: 0.75
                            )
                    }
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.24), radius: 2, x: 0, y: 1)
                    .padding(2)
            }
            .frame(width: 34, height: 20)
            .contentShape(Capsule())
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.84), value: configuration.isOn)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

struct BrandProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var cornerRadius: CGFloat = 10
    var minHeight: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(minHeight: minHeight)
            .background(
                PanelStyle.prominentButtonFill.opacity(isEnabled ? (configuration.isPressed ? 0.84 : 1) : 0.45),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.22 : 0), lineWidth: 0.75)
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct HoverPillButtonStyle: ButtonStyle {
    @State private var hovered = false
    var cornerRadius: CGFloat = 8
    var horizontalPadding: CGFloat = 6
    var verticalPadding: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.13 : hovered ? 0.08 : 0),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onHover { hovered = $0 }
    }
}

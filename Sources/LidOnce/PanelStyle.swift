import AppKit
import SwiftUI

enum PanelStyle {
    static let background = Color(nsColor: NSColor(name: "LidLidPanel") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.105, green: 0.120, blue: 0.150, alpha: 1)
            : NSColor(srgbRed: 0.980, green: 0.978, blue: 0.967, alpha: 1)
    })
    static let backdropTint = Color(nsColor: NSColor(name: "LidLidBackdropTint") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.095, green: 0.112, blue: 0.145, alpha: 0.56)
            : NSColor(srgbRed: 0.985, green: 0.982, blue: 0.970, alpha: 0.62)
    })
    static let accent = Color(nsColor: NSColor(name: "LidLidBlueInk") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.49, green: 0.66, blue: 1.0, alpha: 1)
            : NSColor(srgbRed: 0.13, green: 0.32, blue: 0.76, alpha: 1)
    })
    static let controlTint = Color(nsColor: NSColor(name: "LidLidControlTint") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.29, green: 0.52, blue: 0.98, alpha: 1)
            : NSColor(srgbRed: 0.15, green: 0.35, blue: 0.80, alpha: 1)
    })
    static let cardBackground = Color(nsColor: NSColor(name: "LidLidCard") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.055)
            : NSColor(white: 0.0, alpha: 0.032)
    })
    static let activeCardBackground = Color(nsColor: NSColor(name: "LidLidActiveCard") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.29, green: 0.52, blue: 0.98, alpha: 0.14)
            : NSColor(srgbRed: 0.15, green: 0.35, blue: 0.80, alpha: 0.08)
    })
    static let activeCardBorder = Color(nsColor: NSColor(name: "LidLidActiveBorder") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.49, green: 0.66, blue: 1.0, alpha: 0.34)
            : NSColor(srgbRed: 0.15, green: 0.35, blue: 0.80, alpha: 0.24)
    })
    static let subtleBorder = Color(nsColor: NSColor(name: "LidLidSubtleBorder") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.09)
            : NSColor(white: 0.0, alpha: 0.075)
    })
    static let pillBackground = Color(nsColor: NSColor(name: "LidLidPill") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.49, green: 0.66, blue: 1.0, alpha: 0.14)
            : NSColor(srgbRed: 0.15, green: 0.35, blue: 0.80, alpha: 0.09)
    })
    static let modeInset: CGFloat = 12
    static let cardCorner: CGFloat = 12
}

struct PanelBackdrop: View {
    var material: NSVisualEffectView.Material = .popover

    var body: some View {
        ZStack {
            VisualEffectBackdrop(material: material)
            PanelStyle.backdropTint
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
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

/// Keeps active switches visibly branded cobalt blue regardless of macOS
/// Graphite accent preference or non-key window state.
struct BrandSwitchToggleStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? PanelStyle.controlTint : Color.primary.opacity(0.18))
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.primary.opacity(configuration.isOn ? 0 : 0.10), lineWidth: 0.75)
                    }
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.22), radius: 1.5, x: 0, y: 0.75)
                    .padding(2)
            }
            .frame(width: 32, height: 18)
            .contentShape(Capsule())
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.85), value: configuration.isOn)
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
    var cornerRadius: CGFloat = 9
    var minHeight: CGFloat = 30

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(minHeight: minHeight)
            .background(
                PanelStyle.controlTint.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.16 : 0), lineWidth: 0.75)
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct HoverPillButtonStyle: ButtonStyle {
    @State private var hovered = false
    var cornerRadius: CGFloat = 7
    var horizontalPadding: CGFloat = 6
    var verticalPadding: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.12 : hovered ? 0.075 : 0),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onHover { hovered = $0 }
    }
}

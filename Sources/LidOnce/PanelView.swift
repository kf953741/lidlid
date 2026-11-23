import AppKit
import SwiftUI
import LidOnceCore

struct PanelView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var openTileHovered = false
    @State private var displayTileHovered = false

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        Group {
            if model.options { settings } else { main }
        }
        .padding(16)
        .frame(width: 356)
        .fixedSize(horizontal: false, vertical: true)
        .background { PanelBackdrop() }
        .tint(PanelStyle.controlTint)
        .preferredColorScheme(model.appearance.colorScheme)
        .environment(\.locale, model.language.locale)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.options)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.88), value: model.state.phase)
    }

    // MARK: - Main Panel (Liquid Glass in Dark / Warm Ceramic in Light)

    private var main: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PanelStyle.pillBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(PanelStyle.accent.opacity(isDark ? 0.30 : 0.16), lineWidth: 0.75)
                        }
                    Image(nsImage: GuardianMenuSymbol.image(for: model.menuState,
                                                            displayAwake: model.displayAwakeEnabled, size: 15))
                        .renderingMode(model.menuState.openLidEnabled ? .original : .template)
                        .foregroundStyle(PanelStyle.accent)
                }
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)

                Text(model.brandName)
                    .font(.system(size: 14.5, weight: .semibold))
                    .tracking(-0.2)

                Spacer()

                if let battery = model.state.battery {
                    let low = model.state.onBattery && battery <= 20
                    HStack(spacing: 3.5) {
                        Image(systemName: Self.batterySymbol(level: battery, onBattery: model.state.onBattery))
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(low ? Color.orange : Color.secondary)
                        Text("\(battery)%")
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(low ? Color.orange : Color.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PanelStyle.chromePill, in: Capsule())
                    .accessibilityLabel("\(model.text("当前电量")): \(battery)%")
                }

                Button { model.options = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12.5, weight: .medium))
                        .frame(width: 24, height: 24)
                        .background(PanelStyle.chromePill, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .keyboardShortcut(",", modifiers: .command)
                .accessibilityLabel(model.text("选项"))
                .accessibilityIdentifier("options-button")
                .help(model.text("选项"))
            }

            closedLidHeroCard

            // Apple Control Center style dual tiles
            HStack(alignment: .top, spacing: 10) {
                openAwakeTile
                displayAwakeTile
            }

            if model.store.isStoreEdition, model.store.access != .lifetime || model.store.message != nil {
                StoreAccessView(store: model.store, text: model.text, surface: .panel)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Hero Closed-Lid Power Card

    private var closedLidHeroCard: some View {
        let action = model.closedLidAction
        let armed = model.state.phase == .armed || model.state.phase == .closed
        let inverted = armed // Both Dark Glacier Glass & Light Klein Cobalt use crisp white ink when active
        let dotColor: Color = {
            if armed { return Color(nsColor: NSColor(srgbRed: 0.49, green: 0.83, blue: 0.99, alpha: 1)) }
            return Color.primary.opacity(isDark ? 0.28 : 0.22)
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    PulsingStatusDot(active: armed, color: dotColor)
                    Text(model.text("合盖不休眠"))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(inverted ? Color.white.opacity(0.88) : Color.secondary)
                }
                Spacer(minLength: 4)
                if action == .toggle {
                    Toggle(model.text("合盖不休眠"), isOn: Binding(
                        get: { model.enabled }, set: { if $0 != model.enabled { model.toggle() } }
                    ))
                    .toggleStyle(BrandSwitchToggleStyle(onInvertedHero: inverted && !isDark))
                    .labelsHidden()
                    .disabled(!model.canToggle)
                    .accessibilityIdentifier("session-switch")
                }
            }

            closedLidContent(armed: armed, inverted: inverted)

            if model.sleepStuckDisabled {
                emergencySleepRecoveryNotice
            } else if model.conflict || model.state.error {
                notice(onInvertedHero: inverted)
            }
        }
        .padding(PanelStyle.modeInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if armed {
                RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous)
                    .fill(PanelStyle.heroActiveGradient(dark: isDark))
            } else {
                RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous)
                    .fill(PanelStyle.cardBackground)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous)
                .strokeBorder(PanelStyle.specularRim(dark: isDark, active: armed), lineWidth: armed ? 1 : 0.85)
                .allowsHitTesting(false)
        }
        .shadow(
            color: armed
                ? Color(nsColor: NSColor(srgbRed: 0.12, green: 0.32, blue: 0.88, alpha: isDark ? 0.34 : 0.26))
                : Color.black.opacity(isDark ? 0.18 : 0.055),
            radius: armed ? 14 : 8, x: 0, y: armed ? 6 : 2
        )
    }

    @ViewBuilder private func closedLidContent(armed: Bool, inverted: Bool) -> some View {
        switch model.closedLidAction {
        case .checking:
            if !model.state.error {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.mini)
                    secondary(model.text(model.connected ? "正在检查购买…" : "正在连接盖盖…"))
                }
            }
        case .unsupportedMac:
            VStack(alignment: .leading, spacing: 4) {
                Text(model.text("合盖功能仅支持 MacBook"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                secondary(model.text("未检测到合盖传感器，开盖不休眠与屏幕常亮仍可正常使用。"))
            }
        case .setup:
            secondary(model.text("首次使用需安装免费兼容组件。"))
            Button(action: model.openCompatibility) {
                Text(model.text("设置合盖功能")).frame(maxWidth: .infinity)
            }
            .buttonStyle(BrandProminentButtonStyle())
            .accessibilityIdentifier("compatibility-setup")
        case .tryFree:
            secondary(model.text("试用到期不会自动扣费。"))
            Button {
                model.store.startTrial(compatibilityReady: model.state.compatibilityReady)
            } label: {
                Text(model.text("开始 7 天免费试用")).frame(maxWidth: .infinity)
            }
            .buttonStyle(BrandProminentButtonStyle())
            .disabled(!model.store.canStartTrial(compatibilityReady: model.state.compatibilityReady))
            .accessibilityIdentifier("start-store-trial")
            if let price = model.store.lifetimePrice {
                secondary(String(format: model.text("试用后可选择 %@ 一次买断。"), price))
            }
        case .unlock:
            secondary(model.text("合盖试用已结束"))
            Button(action: model.store.purchaseLifetime) {
                Text(model.store.lifetimePrice.map { model.text("永久解锁合盖 · ") + $0 }
                     ?? model.text("正在加载永久版价格…"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(BrandProminentButtonStyle())
            .disabled(!model.store.canPurchaseLifetime)
            .accessibilityIdentifier("buy-store-lifetime")
        case .toggle:
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(model.title)
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundStyle(inverted ? Color.white : Color.primary)
                        .accessibilityIdentifier("session-state")
                    Spacer(minLength: 4)
                    if !model.changing && !model.enabled {
                        closedLidDurationMenu
                    } else if !model.changing && model.enabled {
                        Text(durationDisplay)
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.white.opacity(0.95))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.18), in: Capsule())
                            .accessibilityIdentifier("active-duration")
                    }
                }
                if !model.state.error, !model.conflict, !model.changing {
                    secondary(model.detail, color: inverted ? Color.white.opacity(0.80) : Color.secondary)
                } else if model.changing, !model.state.error, model.enabled {
                    secondary(model.text(model.state.message), color: inverted ? Color.white.opacity(0.82) : Color.secondary)
                }
            }
        }
    }

    // MARK: - Control Center Dual Tiles

    private var openAwakeTile: some View {
        let active = model.openAwakeEnabled
        let hasError = model.state.openAwakeError
        let subtitle: String = {
            if hasError { return model.text(model.state.openAwakeMessage) }
            if active {
                return model.text(model.state.openAwakeActive ? "合盖时暂停" : model.state.openAwakeMessage)
            }
            return model.text("屏幕可熄灭")
        }()

        return Button {
            model.setOpenAwake(!active)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    ZStack {
                        Circle()
                            .fill(active ? PanelStyle.controlTint : PanelStyle.chromePill)
                        Image(systemName: active ? "bolt.fill" : "bolt")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(active ? Color.white : Color.secondary)
                    }
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                    Spacer(minLength: 4)

                    Text(model.text(active ? "开启" : "关闭"))
                        .font(.system(size: 11, weight: active ? .semibold : .medium))
                        .foregroundStyle(active ? PanelStyle.accent : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 2.5) {
                    Text(model.text("开盖不休眠"))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(active && !isDark ? PanelStyle.accent : Color.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(hasError ? Color.orange : Color.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(
                active ? PanelStyle.openTileActiveBackground : PanelStyle.cardBackground,
                in: RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous)
                    .strokeBorder(
                        active ? AnyShapeStyle(PanelStyle.openTileActiveBorder)
                            : AnyShapeStyle(PanelStyle.specularRim(dark: isDark)),
                        lineWidth: active ? 1.2 : 0.85
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(isDark ? 0.16 : 0.05), radius: 7, x: 0, y: 2)
            .scaleEffect(openTileHovered && model.canToggleOpenAwake && !reduceMotion ? 1.012 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: openTileHovered)
            .contentShape(RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!model.canToggleOpenAwake)
        .opacity(model.canToggleOpenAwake ? 1 : 0.48)
        .onHover { openTileHovered = $0 }
        .accessibilityLabel(model.text("开盖不休眠"))
        .accessibilityValue(model.text(active ? "开启" : "关闭"))
        .accessibilityIdentifier("open-awake-switch")
        .help(model.text("屏幕仍可自动熄灭，合盖时暂停"))
    }

    private var displayAwakeTile: some View {
        let active = model.displayAwakeEnabled
        let errorText = model.state.displayAwake?.error
        let status = model.state.displayAwake
        let subtitle: String = {
            if let errorText { return model.text(errorText) }
            return model.text(active ? "合盖即结束" : "防自动熄屏")
        }()
        let borderStyle: AnyShapeStyle = active
            ? AnyShapeStyle(PanelStyle.displayTileActiveBorder)
            : AnyShapeStyle(PanelStyle.specularRim(dark: isDark))

        return ZStack(alignment: .topTrailing) {
            Button {
                model.setDisplayAwake(!active, duration: model.displayDuration)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(active ? PanelStyle.amberFill : PanelStyle.chromePill)
                        Image(systemName: active ? "sun.max.fill" : "sun.max")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(active ? Color.white : Color.secondary)
                    }
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2.5) {
                        Text(model.text("屏幕常亮"))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(active && !isDark ? PanelStyle.amberAccent : Color.primary)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(errorText != nil ? Color.orange : Color.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                .contentShape(RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!model.canToggleDisplayAwake)
            .accessibilityLabel(model.text("屏幕常亮"))
            .accessibilityValue(model.text(active ? "开启" : "关闭"))
            .accessibilityIdentifier("display-awake-switch")

            Group {
                if active, let status, status.requested {
                    if let deadline = status.deadline {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            let remaining = Int(ceil(max(0, deadline - ProcessInfo.processInfo.systemUptime)))
                            Text(Self.formatCountdown(remaining))
                                .font(.system(size: 11.5, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(PanelStyle.amberAccent)
                        }
                        .accessibilityIdentifier("display-awake-countdown")
                        .allowsHitTesting(false)
                    } else {
                        Label(model.text("持续"), systemImage: "infinity")
                            .labelStyle(.titleOnly)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PanelStyle.amberAccent)
                            .accessibilityIdentifier("display-awake-continuous")
                            .allowsHitTesting(false)
                    }
                } else {
                    compactDurationMenu(DisplayAwakeDuration.allCases, selection: model.displayDuration,
                                        title: model.text("常亮时长"), label: displayShortDurationLabel) { duration in
                        model.displayDuration = duration
                    }
                    .accessibilityIdentifier("display-duration-button")
                }
            }
            .padding(.top, 16)
            .padding(.trailing, 12)
        }
        .background(
            active ? PanelStyle.displayTileActiveBackground : PanelStyle.cardBackground,
            in: RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous)
                .strokeBorder(borderStyle, lineWidth: active ? 1.2 : 0.85)
                .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(isDark ? 0.16 : 0.05), radius: 7, x: 0, y: 2)
        .scaleEffect(displayTileHovered && model.canToggleDisplayAwake && !reduceMotion ? 1.012 : 1.0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: displayTileHovered)
        .opacity(model.canToggleDisplayAwake ? 1 : 0.48)
        .onHover { displayTileHovered = $0 }
        .help(model.text("阻止开盖时自动熄屏"))
    }

    private static func batterySymbol(level: Int, onBattery: Bool) -> String {
        guard onBattery else { return "bolt.fill" }
        switch level {
        case 88...: return "battery.100percent"
        case 63..<88: return "battery.75percent"
        case 38..<63: return "battery.50percent"
        case 13..<38: return "battery.25percent"
        default: return "battery.0percent"
        }
    }

    private static func formatCountdown(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    private func secondary(_ detail: String, color: Color = .secondary) -> some View {
        Text(detail).font(.system(size: 11.5)).foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func displayShortDurationLabel(_ duration: DisplayAwakeDuration) -> String {
        switch duration {
        case .continuous: return model.text("持续")
        case .halfHour: return model.language.resolved() == .english ? "30m" : model.text.duration(duration.rawValue)
        case .oneHour: return model.language.resolved() == .english ? "1h" : model.text.duration(duration.rawValue)
        }
    }

    // MARK: - Settings View

    private var settings: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Button { model.options = false } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11.5, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(PanelStyle.chromePill, in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel(model.text("返回"))
                .accessibilityIdentifier("back-button")
                Text(model.text("选项")).font(.system(size: 14.5, weight: .semibold))
                Spacer()
            }

            settingsCard(title: model.text("通用")) {
                HStack {
                    Text(model.text("登录时启动")).font(.system(size: 12.5))
                    Spacer()
                    Toggle(model.text("登录时启动"), isOn: Binding(get: { model.loginEnabled }, set: model.setLogin))
                        .labelsHidden()
                        .toggleStyle(BrandSwitchToggleStyle())
                }
                if let message = model.loginMessage {
                    Text(model.text(message))
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider().opacity(0.42)
                HStack {
                    Text(model.text("外观")).font(.system(size: 12.5))
                    Spacer()
                    appearancePicker
                }
                Divider().opacity(0.42)
                HStack {
                    Text(model.text("语言")).font(.system(size: 12.5))
                    Spacer()
                    durationMenu(AppLanguage.allCases, selection: model.language,
                                 title: model.text("语言"), label: languageName) { language in
                        model.language = language
                    }
                    .accessibilityIdentifier("language-menu")
                }
            }

            settingsCard(title: model.text("安全保护")) {
                settingRow(model.text("低电量保护"), "10%")
                Divider().opacity(0.42)
                settingRow(model.text("高温保护"), model.text("自动"))
                Divider().opacity(0.42)
                settingRow(model.text("当前电量"),
                           model.state.battery.map { "\($0)%" }
                               ?? model.text(model.state.hasLidSensor ? "读取中" : "接通电源"))
            }

            settingsCard(title: model.text("服务与支持")) {
                if model.store.isStoreEdition {
                    StoreAccessView(store: model.store, text: model.text, surface: .settings)
                    Divider().opacity(0.42)
                }
                settingsActionRow(title: model.text("管理兼容组件"), icon: "puzzlepiece.extension",
                                  trailing: "chevron.right", action: model.openCompatibility)
                Divider().opacity(0.42)
                settingsLinkRow(title: model.text("隐私政策"), icon: "hand.raised",
                                url: URL(string: model.language.resolved() == .simplifiedChinese
                                    ? "https://lidlid.bigsmart.cc/privacy/" : "https://lidlid.bigsmart.cc/en/privacy/")!,
                                id: "privacy-link")
                Divider().opacity(0.42)
                settingsLinkRow(title: model.text("支持与帮助"), icon: "questionmark.circle",
                                url: URL(string: model.language.resolved() == .simplifiedChinese
                                    ? "https://lidlid.bigsmart.cc/support/" : "https://lidlid.bigsmart.cc/en/support/")!,
                                id: "support-link")
            }

            HStack {
                Text(versionCaption)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    HStack(spacing: 4) {
                        Text(model.text("退出盖盖"))
                        Text("⌘Q").foregroundStyle(.tertiary)
                    }
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(HoverPillButtonStyle(cornerRadius: 7, horizontalPadding: 8, verticalPadding: 4))
                .keyboardShortcut("q", modifiers: .command)
                .accessibilityIdentifier("quit-button")
            }
            .padding(.top, 2)
        }
    }

    private var versionCaption: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return version.isEmpty ? model.brandName : "\(model.brandName) \(version)"
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(PanelStyle.cardBackground,
                        in: RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous)
                    .strokeBorder(PanelStyle.specularRim(dark: isDark), lineWidth: 0.85)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(isDark ? 0.14 : 0.045), radius: 6, x: 0, y: 2)
        }
    }

    private func settingsActionRow(title: String, icon: String, trailing: String,
                                   action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(PanelStyle.accent)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Text(title).font(.system(size: 12.5))
                Spacer()
                Image(systemName: trailing)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(HoverPillButtonStyle(cornerRadius: 7, horizontalPadding: 4, verticalPadding: 3))
    }

    private func settingsLinkRow(title: String, icon: String, url: URL, id: String) -> some View {
        Link(destination: url) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Text(title).font(.system(size: 12.5)).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    // MARK: - Menus & Notices

    private var closedLidDurationMenu: some View {
        durationMenu([0, 30, 60, 120, 240, 480], selection: model.maximumMinutes,
                     title: model.text("最长保持"), label: model.text.duration) { minutes in
            model.maximumMinutes = minutes
        }
        .disabled(model.busy)
        .accessibilityIdentifier("duration-menu")
    }

    private func durationMenu<Value: Hashable>(_ options: [Value], selection: Value,
                                               title: String, label: @escaping (Value) -> String,
                                               onSelect: @escaping (Value) -> Void) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button { onSelect(option) } label: {
                    if selection == option {
                        Label(label(option), systemImage: "checkmark")
                    } else {
                        Text(label(option))
                    }
                }
            }
        } label: {
            Text(label(selection))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .font(.system(size: 11, weight: .medium))
        .tint(PanelStyle.accent)
        .fixedSize()
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(PanelStyle.pillBackground, in: Capsule())
        .accessibilityLabel("\(title): \(label(selection))")
    }

    private func compactDurationMenu<Value: Hashable>(_ options: [Value], selection: Value,
                                                      title: String, label: @escaping (Value) -> String,
                                                      onSelect: @escaping (Value) -> Void) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button { onSelect(option) } label: {
                    if selection == option {
                        Label(label(option), systemImage: "checkmark")
                    } else {
                        Text(label(option))
                    }
                }
            }
        } label: {
            Text(label(selection))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .font(.system(size: 10.5, weight: .medium))
        .tint(.secondary)
        .fixedSize()
        .padding(.horizontal, 6.5).padding(.vertical, 2.5)
        .background(PanelStyle.chromePill, in: Capsule())
        .accessibilityLabel("\(title): \(label(selection))")
    }

    private var emergencySleepRecoveryNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.text("系统睡眠仍被禁用"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
            Text(model.text("无法连接兼容服务，请在终端运行以下命令恢复默认睡眠："))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Text("sudo pmset -a disablesleep 0")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                Spacer(minLength: 4)
                Button(model.text(model.copiedRecoveryCommand ? "已复制" : "复制命令"), action: model.copyRecoveryCommand)
                    .buttonStyle(.link)
                    .font(.system(size: 11))
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func notice(onInvertedHero: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.text(model.conflict ? "Clamshell 正在运行" : "需要处理"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(onInvertedHero ? Color.white : Color.orange)
            Text(model.text(model.conflict
                ? (model.conflictQuitHint ? "请在菜单栏或活动监视器中手动退出 Clamshell。" : "退出后即可开启本次合盖不休眠。")
                : model.state.message))
                .font(.system(size: 11))
                .foregroundStyle(onInvertedHero ? Color.white.opacity(0.88) : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.conflict {
                Button(model.text("退出 Clamshell"), action: model.exitReference)
                    .buttonStyle(.link)
                    .font(.system(size: 11))
            } else if model.canReconnect {
                Button(model.text("重新连接"), action: model.reconnect)
                    .buttonStyle(.link)
                    .font(.system(size: 11))
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            onInvertedHero ? Color.black.opacity(0.24) : Color.orange.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private func settingRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }.font(.system(size: 12.5))
    }

    private var appearancePicker: some View {
        HStack(spacing: 2) {
            ForEach(AppAppearance.allCases, id: \.self) { option in
                let selected = model.appearance == option
                Button {
                    model.appearance = option
                } label: {
                    Text(appearanceLabel(option))
                        .font(.system(size: 11, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Color.white : Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(selected ? PanelStyle.prominentButtonFill : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(PanelStyle.chromePill, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.text("外观"))
        .accessibilityIdentifier("appearance-picker")
    }

    private func appearanceLabel(_ appearance: AppAppearance) -> String {
        switch appearance {
        case .system: return model.text("系统")
        case .light: return model.text("浅色")
        case .dark: return model.text("深色")
        }
    }

    private func languageName(_ language: AppLanguage) -> String {
        switch language {
        case .system: return model.text("跟随系统")
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }

    private var durationDisplay: String {
        if model.enabled, let deadline = model.state.deadline {
            let time = Date(timeIntervalSince1970: deadline).formatted(
                Date.FormatStyle(date: .omitted, time: .shortened).locale(model.language.locale)
            )
            return "\(model.text("最晚结束")) \(time)"
        }
        return model.durationLabel
    }
}

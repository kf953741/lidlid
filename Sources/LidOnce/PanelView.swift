import AppKit
import SwiftUI
import LidOnceCore

struct PanelView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if model.options { settings } else { main }
        }
        .padding(16)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .background { PanelBackdrop() }
        .tint(PanelStyle.controlTint)
        .environment(\.locale, model.language.locale)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: model.options)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.state.phase)
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(nsImage: GuardianMenuSymbol.image(for: model.menuState,
                                                        displayAwake: model.displayAwakeEnabled, size: 20))
                    .renderingMode(model.menuState.openLidEnabled ? .original : .template)
                    .foregroundStyle(PanelStyle.accent)
                    .accessibilityHidden(true)
                Text(model.brandName).font(.system(size: 14, weight: .semibold))
                Spacer()
                Button { model.options = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13.5, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(HoverPillButtonStyle(cornerRadius: 7, horizontalPadding: 3, verticalPadding: 3))
                .foregroundStyle(.secondary)
                .keyboardShortcut(",", modifiers: .command)
                .accessibilityLabel(model.text("选项"))
                .accessibilityIdentifier("options-button")
                .help(model.text("选项"))
            }

            closedLidCard

            VStack(alignment: .leading, spacing: 0) {
                openAwakeRow
                    .padding(.vertical, 9)
                Divider().opacity(0.45)
                displayAwakeRow
                    .padding(.vertical, 9)
            }
            .padding(.horizontal, PanelStyle.modeInset)
            .background(PanelStyle.cardBackground,
                        in: RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous)
                    .strokeBorder(PanelStyle.subtleBorder, lineWidth: 0.75)
                    .allowsHitTesting(false)
            }

            if model.store.isStoreEdition, model.store.access != .lifetime || model.store.message != nil {
                StoreAccessView(store: model.store, text: model.text, surface: .panel)
            }
        }
    }

    private var closedLidCard: some View {
        let action = model.closedLidAction
        let armed = model.state.phase == .armed || model.state.phase == .closed
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                modeLabel("合盖不休眠", icon: "laptopcomputer", active: armed)
                Spacer(minLength: 4)
                if action == .toggle {
                    if !model.changing && !model.enabled {
                        closedLidDurationMenu
                    }
                    Toggle(model.text("合盖不休眠"), isOn: Binding(
                        get: { model.enabled }, set: { if $0 != model.enabled { model.toggle() } }
                    ))
                    .toggleStyle(BrandSwitchToggleStyle())
                    .labelsHidden()
                    .disabled(!model.canToggle)
                    .accessibilityIdentifier("session-switch")
                }
            }
            closedLidContent(armed: armed)
            if model.conflict || model.state.error { notice }
        }
        .padding(PanelStyle.modeInset)
        .background(armed ? PanelStyle.activeCardBackground : PanelStyle.cardBackground,
                    in: RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous)
                .strokeBorder(armed ? PanelStyle.activeCardBorder : PanelStyle.subtleBorder, lineWidth: armed ? 1 : 0.75)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder private func closedLidContent(armed: Bool) -> some View {
        switch model.closedLidAction {
        case .checking:
            if !model.state.error {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.mini)
                    secondary(model.text(model.connected ? "正在检查购买…" : "正在连接盖盖…"))
                }
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
            .disabled(!model.store.canPurchase)
            .accessibilityIdentifier("buy-store-lifetime")
        case .toggle:
            HStack(spacing: 8) {
                Label(model.title, systemImage: armed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11.5, weight: armed ? .semibold : .medium))
                    .foregroundStyle(armed ? PanelStyle.accent : Color.secondary)
                    .padding(.horizontal, armed ? 7 : 0)
                    .padding(.vertical, armed ? 2.5 : 0)
                    .background(armed ? PanelStyle.pillBackground : Color.clear, in: Capsule())
                    .accessibilityIdentifier("session-state")
                Spacer(minLength: 2)
                if !model.changing && model.enabled {
                    secondary(durationDisplay)
                        .monospacedDigit()
                        .accessibilityIdentifier("active-duration")
                }
            }
            if !model.state.error, !model.conflict, !model.changing {
                secondary(model.detail)
            } else if model.changing, !model.state.error, model.enabled {
                secondary(model.text(model.state.message))
            }
        }
    }

    private var openAwakeRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                modeLabel("开盖不休眠", icon: model.openAwakeEnabled ? "bolt.fill" : "bolt",
                          active: model.openAwakeEnabled)
                Spacer(minLength: 4)
                Toggle(model.text("开盖不休眠"), isOn: Binding(
                    get: { model.openAwakeEnabled }, set: model.setOpenAwake
                ))
                .toggleStyle(BrandSwitchToggleStyle())
                .labelsHidden()
                .disabled(!model.canToggleOpenAwake)
                .accessibilityIdentifier("open-awake-switch")
            }
            if model.openAwakeEnabled || model.state.openAwakeError {
                secondary(model.text(model.displayAwakeEnabled && !model.state.openAwakeError
                                     ? "合盖时暂停" : model.state.openAwakeMessage),
                          color: model.state.openAwakeError ? .orange : .secondary)
                    .padding(.leading, 26)
            }
        }
        .help(model.text("屏幕仍可自动熄灭，合盖时暂停"))
    }

    private var displayAwakeRow: some View {
        let active = model.displayAwakeEnabled
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                modeLabel("屏幕常亮", icon: active ? "sun.max.fill" : "sun.max", active: active)
                Spacer(minLength: 4)
                if !active {
                    durationMenu(DisplayAwakeDuration.allCases, selection: model.displayDuration,
                                 title: model.text("常亮时长"), label: displayDurationLabel) { duration in
                        model.displayDuration = duration
                    }
                    .accessibilityIdentifier("display-duration-button")
                }
                Toggle(model.text("屏幕常亮"), isOn: Binding(
                    get: { active },
                    set: { model.setDisplayAwake($0, duration: model.displayDuration) }
                ))
                .toggleStyle(BrandSwitchToggleStyle())
                .labelsHidden()
                .disabled(!model.canToggleDisplayAwake)
                .accessibilityIdentifier("display-awake-switch")
            }
            if let error = model.state.displayAwake?.error {
                secondary(model.text(error), color: .orange)
                    .padding(.leading, 26)
            }
            if active, let status = model.state.displayAwake, status.requested {
                if let deadline = status.deadline {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let remaining = Int(ceil(max(0, deadline - ProcessInfo.processInfo.systemUptime)))
                        displayAwakeBadge("剩余时间",
                                          detail: Self.formatCountdown(remaining),
                                          icon: "timer")
                    }
                    .accessibilityIdentifier("display-awake-countdown")
                } else {
                    displayAwakeBadge("持续常亮", detail: model.text("合盖即结束"), icon: "infinity")
                        .accessibilityIdentifier("display-awake-continuous")
                }
            }
        }
        .help(model.text("阻止开盖时自动熄屏"))
    }

    private static func formatCountdown(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    private func modeLabel(_ title: String, icon: String, active: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12.5, weight: .medium))
                .frame(width: 18)
                .foregroundStyle(active ? PanelStyle.accent : Color.secondary)
                .accessibilityHidden(true)
            Text(model.text(title))
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
        }
    }

    private func secondary(_ detail: String, color: Color = .secondary) -> some View {
        Text(detail).font(.system(size: 11.5)).foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func displayDurationLabel(_ duration: DisplayAwakeDuration) -> String {
        duration == .continuous ? model.text("持续") : model.text.duration(duration.rawValue)
    }

    private func displayAwakeBadge(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Label(model.text(title), systemImage: icon)
            Spacer(minLength: 0)
            Text(detail).monospacedDigit()
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(PanelStyle.accent)
        .frame(height: 22)
        .padding(.horizontal, 8)
        .background(PanelStyle.pillBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 6) {
                Button { model.options = false } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(HoverPillButtonStyle(cornerRadius: 7, horizontalPadding: 3, verticalPadding: 3))
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel(model.text("返回"))
                .accessibilityIdentifier("back-button")
                Text(model.text("选项")).font(.system(size: 14, weight: .semibold))
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
                Divider().opacity(0.45)
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
                Divider().opacity(0.45)
                settingRow(model.text("高温保护"), model.text("自动"))
                Divider().opacity(0.45)
                settingRow(model.text("当前电量"), model.state.battery.map { "\($0)%" } ?? model.text("读取中"))
            }

            settingsCard(title: model.text("服务与支持")) {
                if model.store.isStoreEdition {
                    StoreAccessView(store: model.store, text: model.text, surface: .settings)
                    Divider().opacity(0.45)
                }
                settingsActionRow(title: model.text("管理兼容组件"), icon: "puzzlepiece.extension",
                                  trailing: "chevron.right", action: model.openCompatibility)
                Divider().opacity(0.45)
                settingsLinkRow(title: model.text("隐私政策"), icon: "hand.raised",
                                url: URL(string: model.language.resolved() == .simplifiedChinese
                                    ? "https://lidlid.bigsmart.cc/privacy/" : "https://lidlid.bigsmart.cc/en/privacy/")!,
                                id: "privacy-link")
                Divider().opacity(0.45)
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
                .buttonStyle(HoverPillButtonStyle(cornerRadius: 6, horizontalPadding: 8, verticalPadding: 4))
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
            .padding(.horizontal, PanelStyle.modeInset)
            .padding(.vertical, 10)
            .background(PanelStyle.cardBackground,
                        in: RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PanelStyle.cardCorner, style: .continuous)
                    .strokeBorder(PanelStyle.subtleBorder, lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
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
        .padding(.horizontal, 7).padding(.vertical, 2.5)
        .background(PanelStyle.pillBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityLabel("\(title): \(label(selection))")
    }

    private var notice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.text(model.conflict ? "Clamshell 正在运行" : "需要处理"))
                .font(.system(size: 12, weight: .semibold))
            Text(model.text(model.conflict ? "退出后即可开启本次合盖不休眠。" : model.state.message))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.conflict {
                Button(model.text("退出 Clamshell"), action: model.exitReference)
                    .buttonStyle(.link)
                    .font(.system(size: 11))
            }
        }
        .foregroundStyle(.orange)
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func settingRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }.font(.system(size: 12.5))
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

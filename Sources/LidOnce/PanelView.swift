import AppKit
import SwiftUI
import LidOnceCore

private enum PanelStyle {
    static let background = Color(nsColor: NSColor(name: "LidLidPanel") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 0.115, green: 0.125, blue: 0.125, alpha: 1)
            : NSColor(calibratedRed: 0.980, green: 0.980, blue: 0.969, alpha: 1)
    })
    static let accent = Color(nsColor: NSColor(name: "LidLidAccent") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 0.40, green: 0.76, blue: 0.65, alpha: 1)
            : NSColor(calibratedRed: 0.13, green: 0.40, blue: 0.34, alpha: 1)
    })
}

struct PanelView: View {
    @ObservedObject var model: AppModel
    @State private var displayDuration: DisplayAwakeDuration = .halfHour
    @State private var choosingDisplayDuration = false

    var body: some View {
        Group {
            if model.options { settings } else { main }
        }
        .padding(18)
        .frame(width: 352)
        .fixedSize(horizontal: false, vertical: true)
        .background(PanelStyle.background)
        .tint(PanelStyle.accent)
        .environment(\.locale, model.language.locale)
        .animation(.easeInOut(duration: 0.16), value: model.options)
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(nsImage: GuardianMenuSymbol.image(for: model.menuState, size: 20))
                    .renderingMode(model.menuState.openLidEnabled ? .original : .template)
                    .foregroundStyle(PanelStyle.accent)
                    .accessibilityHidden(true)
                Text(model.brandName).font(.system(size: 14, weight: .semibold))
                Spacer()
                Button { model.options = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(model.text("选项"))
                .accessibilityIdentifier("options-button")
                .help(model.text("选项"))
            }

            closedLidCard

            VStack(alignment: .leading, spacing: 6) {
                openAwakeRow
                Divider().opacity(0.7)
                displayAwakeRow
            }
            .padding(.horizontal, 4)

            if model.store.isStoreEdition, model.store.access != .lifetime || model.store.message != nil {
                StoreAccessView(store: model.store, text: model.text, surface: .panel)
            }
        }
    }

    private var closedLidCard: some View {
        let action = model.closedLidAction
        let armed = model.state.phase == .armed || model.state.phase == .closed
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                modeLabel("合盖不休眠", icon: "laptopcomputer", active: armed)
                Spacer(minLength: 0)
                if action == .toggle {
                    Toggle(model.text("合盖不休眠"), isOn: Binding(
                        get: { model.enabled }, set: { if $0 != model.enabled { model.toggle() } }
                    ))
                    .toggleStyle(.switch).labelsHidden().controlSize(.small)
                    .disabled(!model.canToggle)
                    .accessibilityIdentifier("session-switch")
                }
            }
            closedLidContent(armed: armed)
            if model.conflict || model.state.error { notice }
        }
        .padding(12)
        .background((armed ? PanelStyle.accent : Color.primary).opacity(armed ? 0.08 : 0.045),
                    in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(PanelStyle.accent.opacity(armed ? 0.24 : 0), lineWidth: 1)
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
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("compatibility-setup")
        case .tryFree:
            secondary(model.text("试用到期不会自动扣费。"))
            Button {
                model.store.startTrial(compatibilityReady: model.state.compatibilityReady)
            } label: {
                Text(model.text("开始 7 天免费试用")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
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
            .buttonStyle(.borderedProminent)
            .disabled(!model.store.canPurchase)
            .accessibilityIdentifier("buy-store-lifetime")
        case .toggle:
            HStack(spacing: 8) {
                Label(model.title, systemImage: armed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: armed ? .semibold : .regular))
                    .foregroundStyle(armed ? PanelStyle.accent : Color.secondary)
                    .accessibilityIdentifier("session-state")
                Spacer(minLength: 2)
                if !model.changing {
                    if model.enabled {
                        secondary(durationDisplay).accessibilityIdentifier("active-duration")
                    } else {
                        durationMenu
                    }
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
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                modeLabel("开盖不休眠", icon: "bolt", active: model.openAwakeEnabled)
                Spacer(minLength: 0)
                Toggle(model.text("开盖不休眠"), isOn: Binding(
                    get: { model.openAwakeEnabled }, set: model.setOpenAwake
                ))
                .toggleStyle(.switch).labelsHidden().controlSize(.small)
                .disabled(!model.canToggleOpenAwake)
                .accessibilityIdentifier("open-awake-switch")
            }
            .frame(minHeight: 29)
            if model.openAwakeEnabled || model.state.openAwakeError {
                secondary(model.text(model.displayAwakeEnabled && !model.state.openAwakeError
                                     ? "合盖时暂停" : model.state.openAwakeMessage),
                          color: model.state.openAwakeError ? .orange : .secondary)
                    .padding(.leading, 28)
            }
        }
        .help(model.text("屏幕仍可自动熄灭，合盖时暂停"))
    }

    private var displayAwakeRow: some View {
        let active = model.displayAwakeEnabled
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                modeLabel("屏幕常亮", icon: active ? "sun.max.fill" : "sun.max", active: active)
                Spacer(minLength: 2)
                if !active {
                    Button { choosingDisplayDuration.toggle() } label: {
                        HStack(spacing: 4) {
                            Text(displayDuration == .halfHour ? model.text("30 分钟") : displayDurationLabel(displayDuration))
                                .fixedSize()
                            Image(systemName: choosingDisplayDuration ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.vertical, 4).padding(.horizontal, 6)
                        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(model.text("常亮时长") + " · " + displayDurationLabel(displayDuration))
                    .accessibilityIdentifier("display-duration-button")
                }
                Toggle(model.text("屏幕常亮"), isOn: Binding(
                    get: { active },
                    set: {
                        choosingDisplayDuration = false
                        model.setDisplayAwake($0, duration: displayDuration)
                    }
                ))
                .toggleStyle(.switch).labelsHidden().controlSize(.small)
                .disabled(!model.canToggleDisplayAwake)
                .accessibilityIdentifier("display-awake-switch")
            }
            .frame(minHeight: 29)
            if let error = model.state.displayAwake?.error {
                secondary(model.text(error), color: .orange)
            }
            if active, let status = model.state.displayAwake, status.requested {
                if let deadline = status.deadline {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let remaining = Int(ceil(max(0, deadline - ProcessInfo.processInfo.systemUptime)))
                        displayAwakeBadge("剩余时间",
                                          detail: String(format: "%02d:%02d", remaining / 60, remaining % 60),
                                          icon: "timer")
                    }
                    .accessibilityIdentifier("display-awake-countdown")
                } else {
                    displayAwakeBadge("持续常亮", detail: model.text("合盖即结束"), icon: "infinity")
                        .accessibilityIdentifier("display-awake-continuous")
                }
            } else if choosingDisplayDuration {
                Picker(model.text("常亮时长"), selection: $displayDuration) {
                    ForEach(DisplayAwakeDuration.allCases, id: \.self) { duration in
                        Text(displayDurationLabel(duration)).tag(duration)
                    }
                }
                .pickerStyle(.segmented).labelsHidden().controlSize(.small)
                .onChange(of: displayDuration) { _, _ in choosingDisplayDuration = false }
                .accessibilityIdentifier("display-awake-duration")
            }
        }
        .help(model.text("阻止开盖时自动熄屏"))
    }

    private func modeLabel(_ title: String, icon: String, active: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 20)
                .foregroundStyle(active ? PanelStyle.accent : Color.secondary)
                .accessibilityHidden(true)
            Text(model.text(title)).font(.system(size: 13, weight: .semibold))
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func secondary(_ detail: String, color: Color = .secondary) -> some View {
        Text(detail).font(.system(size: 12)).foregroundStyle(color)
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
        .frame(height: 20)
        .padding(.horizontal, 8)
        .background(PanelStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
        .accessibilityElement(children: .combine)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button { model.options = false } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 18, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.text("返回"))
                .accessibilityIdentifier("back-button")
                Text(model.text("选项")).font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            HStack {
                Text(model.text("登录时启动")).font(.system(size: 12))
                Spacer()
                Toggle(model.text("登录时启动"), isOn: Binding(get: { model.loginEnabled }, set: model.setLogin))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }.padding(.top, 24)
            if let message = model.loginMessage {
                Text(model.text(message))
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            HStack {
                Text(model.text("语言"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Button {
                            model.language = language
                        } label: {
                            if model.language == language {
                                Label(languageName(language), systemImage: "checkmark")
                            } else {
                                Text(languageName(language))
                            }
                        }
                    }
                } label: {
                    Text(languageName(model.language)).font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.visible)
                .tint(.primary)
                .fixedSize()
                .accessibilityLabel(model.text("语言"))
                .accessibilityIdentifier("language-menu")
            }.padding(.top, 18)
            Divider().opacity(0.6).padding(.vertical, 20)
            settingRow(model.text("低电量保护"), "10%")
            settingRow(model.text("高温保护"), model.text("自动")).padding(.top, 16)
            settingRow(model.text("当前电量"), model.state.battery.map { "\($0)%" } ?? model.text("读取中")).padding(.top, 16)
            if model.store.isStoreEdition {
                StoreAccessView(store: model.store, text: model.text, surface: .settings)
                    .padding(.top, 16)
            }
            Button(model.text("管理兼容组件"), action: model.openCompatibility)
                .buttonStyle(.link).font(.system(size: 11)).padding(.top, 16)
            HStack(spacing: 16) {
                Link(model.text("隐私政策"), destination: URL(string: model.language.resolved() == .simplifiedChinese
                    ? "https://lidlid.vercel.app/privacy/" : "https://lidlid.vercel.app/en/privacy/")!)
                    .accessibilityIdentifier("privacy-link")
                Link(model.text("支持与帮助"), destination: URL(string: model.language.resolved() == .simplifiedChinese
                    ? "https://lidlid.vercel.app/support/" : "https://lidlid.vercel.app/en/support/")!)
                    .accessibilityIdentifier("support-link")
            }
            .font(.system(size: 11))
            .padding(.top, 16)
            Divider().opacity(0.6).padding(.top, 20).padding(.bottom, 16)
            HStack {
                Text("\(model.brandName) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(model.text("退出盖盖")) { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("quit-button")
            }
        }
    }

    private var durationMenu: some View {
        Menu {
            ForEach([0, 30, 60, 120, 240, 480], id: \.self) { minutes in
                Button {
                    model.maximumMinutes = minutes
                } label: {
                    if model.maximumMinutes == minutes {
                        Label(model.text.duration(minutes), systemImage: "checkmark")
                    } else {
                        Text(model.text.duration(minutes))
                    }
                }
            }
        } label: {
            Text(durationDisplay).font(.system(size: 11, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .tint(.primary)
        .fixedSize()
        .disabled(model.busy)
        .accessibilityLabel("\(model.text("最长保持")): \(durationDisplay)")
        .accessibilityIdentifier("duration-menu")
    }

    private var notice: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(model.text(model.conflict ? "Clamshell 正在运行" : "需要处理"))
                .font(.system(size: 12, weight: .medium))
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
    }

    private func settingRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }.font(.system(size: 12))
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

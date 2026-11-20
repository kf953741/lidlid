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

    var body: some View {
        Group {
            if model.options { settings } else { main }
        }
        .padding(24)
        .frame(width: 326)
        .fixedSize(horizontal: false, vertical: true)
        .background(PanelStyle.background)
        .tint(PanelStyle.accent)
        .environment(\.locale, model.language.locale)
        .animation(.easeInOut(duration: 0.16), value: model.options)
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(nsImage: GuardianMenuSymbol.image(for: model.menuState, size: 20))
                    .renderingMode(model.menuState.openLidEnabled ? .original : .template)
                    .foregroundStyle(PanelStyle.accent)
                    .accessibilityHidden(true)
                Text(model.brandName)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button { model.options = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(model.text("选项"))
                .accessibilityIdentifier("options-button")
                .help(model.text("选项"))
            }

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.title)
                        .font(.system(size: 28, weight: .medium))
                        .tracking(-0.6)
                        .accessibilityIdentifier("session-state")
                    Text(model.text("本次合盖不休眠"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Toggle(model.text("本次合盖不休眠"), isOn: Binding(
                    get: { model.enabled },
                    set: { value in if value != model.enabled { model.toggle() } }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.regular)
                .disabled(!model.canToggle)
                .accessibilityIdentifier("session-switch")
            }
            .padding(.top, 28)

            Text(model.detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)

            if !model.state.compatibilityReady && !model.enabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.text(model.state.compatibilityMessage))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(model.text("设置免费兼容组件"), action: model.openCompatibility)
                        .buttonStyle(.link).font(.system(size: 12))
                        .accessibilityIdentifier("compatibility-setup")
                }.padding(.top, 16)
            }
            if model.conflict || model.state.error {
                notice.padding(.top, 16)
            }

            Divider().opacity(0.6).padding(.top, 22).padding(.bottom, 15)
            HStack {
                Text(model.text("最长保持"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                durationMenu
            }
            Text(model.text("电量降至 10% 或过热时自动结束"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)

            Divider().opacity(0.6).padding(.vertical, 18)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.text("开盖不休眠")).font(.system(size: 12, weight: .medium))
                    Text(model.text(model.displayAwakeEnabled && !model.state.openAwakeError
                                    ? "合盖时暂停" : model.state.openAwakeMessage))
                        .font(.system(size: 11))
                        .foregroundStyle(model.state.openAwakeError ? Color.orange : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle(model.text("开盖不休眠"), isOn: Binding(
                    get: { model.openAwakeEnabled }, set: model.setOpenAwake
                ))
                .toggleStyle(.switch).labelsHidden().controlSize(.small)
                .disabled(!model.canToggleOpenAwake)
                .accessibilityIdentifier("open-awake-switch")
            }

            displayAwakeCard.padding(.top, 14)

            if model.store.isStoreEdition {
                Divider().opacity(0.6).padding(.vertical, 18)
                StoreAccessView(store: model.store, text: model.text, compatibilityReady: model.state.compatibilityReady)
            }

        }
    }

    private var displayAwakeCard: some View {
        let active = model.displayAwakeEnabled
        let emphasis = active ? PanelStyle.accent : Color.secondary
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: active ? "sun.max.fill" : "sun.max")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(emphasis)
                    .frame(width: 28, height: 28)
                    .background(emphasis.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.text("屏幕常亮"))
                        .font(.system(size: 12, weight: .semibold))
                    Text(model.text(model.state.displayAwake?.error ?? "阻止开盖时自动熄屏"))
                        .font(.system(size: 11))
                        .foregroundStyle(model.state.displayAwake?.error == nil ? Color.secondary : .orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle(model.text("屏幕常亮"), isOn: Binding(
                    get: { active },
                    set: { model.setDisplayAwake($0, duration: displayDuration) }
                ))
                .toggleStyle(.switch).labelsHidden().controlSize(.small)
                .disabled(!model.canToggleDisplayAwake)
                .accessibilityIdentifier("display-awake-switch")
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
            } else {
                Picker(model.text("常亮时长"), selection: $displayDuration) {
                    ForEach(DisplayAwakeDuration.allCases, id: \.self) { duration in
                        Text(duration == .continuous ? model.text("持续") : model.text.duration(duration.rawValue))
                            .tag(duration)
                    }
                }
                .pickerStyle(.segmented).labelsHidden().controlSize(.small)
                .disabled(!model.canToggleDisplayAwake)
                .accessibilityIdentifier("display-awake-duration")
            }
        }
        .padding(10)
        .background(emphasis.opacity(active ? 0.06 : 0.045), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(emphasis.opacity(active ? 0.24 : 0.14), lineWidth: 1)
                .allowsHitTesting(false)
        }
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
            Text(durationDisplay).font(.system(size: 12))
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

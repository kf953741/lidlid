import AppKit
import SwiftUI

private enum PanelStyle {
    static let background = Color(nsColor: NSColor(name: "LidunePanel") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 0.115, green: 0.125, blue: 0.125, alpha: 1)
            : NSColor(calibratedRed: 0.980, green: 0.980, blue: 0.969, alpha: 1)
    })
    static let accent = Color(nsColor: NSColor(name: "LiduneAccent") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 0.40, green: 0.76, blue: 0.65, alpha: 1)
            : NSColor(calibratedRed: 0.13, green: 0.40, blue: 0.34, alpha: 1)
    })
}

struct PanelView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if model.options { settings } else { main }
        }
        .padding(24)
        .frame(width: 326)
        .fixedSize(horizontal: false, vertical: true)
        .background(PanelStyle.background)
        .tint(PanelStyle.accent)
        .animation(.easeInOut(duration: 0.16), value: model.options)
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(nsImage: OwlMenuSymbol.image(for: .on, size: 20))
                    .renderingMode(.template)
                    .foregroundStyle(PanelStyle.accent)
                    .accessibilityHidden(true)
                Text("Lidune")
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
                .accessibilityLabel("选项")
                .accessibilityIdentifier("options-button")
                .help("选项")
            }

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.title)
                        .font(.system(size: 28, weight: .medium))
                        .tracking(-0.6)
                        .accessibilityIdentifier("session-state")
                    Text("本次合盖不休眠")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Toggle("本次合盖不休眠", isOn: Binding(
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

            if model.conflict || model.state.error {
                notice.padding(.top, 16)
            }

            Divider().opacity(0.6).padding(.top, 22).padding(.bottom, 15)
            HStack {
                Text("最长保持")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                durationMenu
            }
            Text("电量降至 10% 或过热时自动结束")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 16)
        }
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
                .accessibilityLabel("返回")
                .accessibilityIdentifier("back-button")
                Text("选项").font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            HStack {
                Text("登录时启动").font(.system(size: 12))
                Spacer()
                Toggle("登录时启动", isOn: Binding(get: { model.loginEnabled }, set: model.setLogin))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }.padding(.top, 24)
            if let message = model.loginMessage {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            Divider().opacity(0.6).padding(.vertical, 20)
            settingRow("低电量保护", "10%")
            settingRow("高温保护", "自动").padding(.top, 16)
            settingRow("当前电量", model.state.battery.map { "\($0)%" } ?? "读取中").padding(.top, 16)
            Text("保持通风，放入包内前先结束本次。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)
            Divider().opacity(0.6).padding(.top, 20).padding(.bottom, 16)
            HStack {
                Text("Lidune 1.1")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("退出 Lidune") { NSApp.terminate(nil) }
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
                        Label(durationName(minutes), systemImage: "checkmark")
                    } else {
                        Text(durationName(minutes))
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
        .accessibilityLabel("最长保持：\(model.durationLabel)")
        .accessibilityIdentifier("duration-menu")
    }

    private var notice: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(model.conflict ? "Clamshell 正在运行" : "需要处理")
                .font(.system(size: 12, weight: .medium))
            Text(model.conflict ? "退出后即可开启本次合盖不休眠。" : model.state.message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.conflict {
                Button("退出 Clamshell", action: model.exitReference)
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

    private func durationName(_ minutes: Int) -> String {
        if minutes == 0 { return "直到开盖" }
        if minutes < 60 { return "\(minutes) 分钟" }
        return "\(minutes / 60) 小时"
    }

    private var durationDisplay: String {
        if model.enabled, let deadline = model.state.deadline {
            return "最晚 \(Date(timeIntervalSince1970: deadline).formatted(date: .omitted, time: .shortened))"
        }
        return model.durationLabel
    }
}

import AppKit
import SwiftUI
import ServiceManagement
import LidLidServiceProtocol
import LidOnceSystem
import LidOnceCore

private enum ComponentTheme {
    static let background = Color(nsColor: NSColor(name: "LidLidComponentBG") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.105, green: 0.120, blue: 0.150, alpha: 1)
            : NSColor(srgbRed: 0.980, green: 0.978, blue: 0.967, alpha: 1)
    })
    static let accent = Color(nsColor: NSColor(name: "LidLidComponentAccent") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.49, green: 0.66, blue: 1.0, alpha: 1)
            : NSColor(srgbRed: 0.13, green: 0.32, blue: 0.76, alpha: 1)
    })
    static let controlTint = Color(nsColor: NSColor(name: "LidLidComponentTint") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.29, green: 0.52, blue: 0.98, alpha: 1)
            : NSColor(srgbRed: 0.15, green: 0.35, blue: 0.80, alpha: 1)
    })
    static let cardBackground = Color(nsColor: NSColor(name: "LidLidComponentCard") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.055)
            : NSColor(white: 0.0, alpha: 0.032)
    })
    static let subtleBorder = Color(nsColor: NSColor(name: "LidLidComponentBorder") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.09)
            : NSColor(white: 0.0, alpha: 0.075)
    })
}

private struct ComponentProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                ComponentTheme.controlTint.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.16 : 0), lineWidth: 0.75)
            }
    }
}

final class ComponentModel: ObservableObject {
    @Published var busy = false
    @Published var ready = false
    @Published var state = SMAppService.Status.notRegistered
    @Published var message = ""
    @Published var language: AppLanguage = AppLanguage(
        rawValue: UserDefaults.standard.string(forKey: "compatibilityLanguage") ?? ""
    ) ?? .system {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "compatibilityLanguage") }
    }
    private let client = CompatibilityClient()
    private var service: SMAppService { .daemon(plistName: CompatibilityService.plist) }
    var text: AppText { AppText(language: language) }
    var inApplications: Bool { Bundle.main.bundleURL.deletingLastPathComponent().path == "/Applications" }
    var installed: Bool { state == .enabled || state == .requiresApproval }
    func refresh() {
        state = service.status
        ready = false
        if state == .enabled {
            client.status { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let status):
                    self.ready = !status.recoveryPending
                    self.message = status.recoveryPending ? "兼容组件正在恢复睡眠，请保持开盖" : "兼容组件已就绪"
                case .failure(let error): self.message = error.localizedDescription
                }
            }
        }
    }
    func install() {
        guard inApplications else { message = "请先把兼容组件拖到应用程序文件夹"; return }
        do {
            try service.register()
            message = "请在系统设置中允许盖盖兼容组件"
        } catch {
            if service.status != .requiresApproval { message = error.localizedDescription }
        }
        refresh()
    }
    func remove() {
        busy = true
        // Do not unregister while a persisted override remains. If the daemon
        // cannot answer, let launchd keep it alive for recovery, not remove it.
        client.prepareForRemoval { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error): self.message = error.localizedDescription; self.busy = false
            case .success:
                Task { @MainActor in
                    do { try await self.service.unregister(); self.message = "睡眠已恢复，可以移除兼容组件" }
                    catch { self.message = error.localizedDescription }
                    self.busy = false; self.refresh()
                }
            }
        }
    }
}

@main
struct CompatibilityApp: App {
    @StateObject private var model = ComponentModel()
    var body: some Scene {
        WindowGroup("LidLid Compatibility") {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 50, height: 50)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.text("盖盖兼容组件")).font(.system(size: 19, weight: .semibold))
                        Text(model.text("让合盖运行更可靠")).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Language", selection: $model.language) {
                        Text("系统 / System").tag(AppLanguage.system)
                        Text("中文").tag(AppLanguage.simplifiedChinese)
                        Text("English").tag(AppLanguage.english)
                    }.labelsHidden().frame(width: 124)
                }

                Text(model.text("免费组件，由你在 macOS 中授权。仅在盖盖会话期间管理系统睡眠；开盖、退出或连接超时后恢复原设置。"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: model.ready ? "checkmark.circle.fill"
                              : model.state == .requiresApproval ? "exclamationmark.shield.fill"
                              : "person.badge.key")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(model.ready ? ComponentTheme.accent
                                             : model.state == .requiresApproval ? .orange : .secondary)
                        Text(model.text(model.ready ? "兼容组件已就绪"
                                        : model.state == .enabled ? "正在连接兼容服务…"
                                        : model.state == .requiresApproval ? "请在系统设置中允许盖盖兼容组件"
                                        : "请先安装并授权盖盖兼容组件"))
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                    if !model.message.isEmpty && model.message != "兼容组件已就绪" {
                        Text(model.text(model.message))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(model.ready ? ComponentTheme.controlTint.opacity(0.10) : ComponentTheme.cardBackground,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(model.ready ? ComponentTheme.accent.opacity(0.32) : ComponentTheme.subtleBorder,
                                      lineWidth: model.ready ? 1 : 0.75)
                }

                HStack(spacing: 10) {
                    if !model.inApplications {
                        Button(model.text("打开应用程序文件夹")) {
                            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
                        }
                        .buttonStyle(ComponentProminentButtonStyle())
                    } else if !model.installed {
                        Button(model.text("安装兼容服务")) { model.install() }
                            .buttonStyle(ComponentProminentButtonStyle())
                    } else if model.state == .requiresApproval {
                        Button(model.text("打开系统设置")) { SMAppService.openSystemSettingsLoginItems() }
                            .buttonStyle(ComponentProminentButtonStyle())
                    }
                    Button(model.text("刷新状态")) { model.refresh() }
                    Spacer()
                    if model.state == .enabled {
                        Button(role: .destructive) { model.remove() } label: {
                            Text(model.text("恢复睡眠并移除服务"))
                        }
                    }
                }
                .disabled(model.busy)

                Text(model.text("需要主动睡眠时，请先关闭盖盖。移除组件前，请先点“恢复睡眠并移除服务”。"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(26)
            .frame(width: 550)
            .background(ComponentTheme.background)
            .tint(ComponentTheme.controlTint)
            .environment(\.locale, model.language.locale)
            .onAppear { model.refresh() }
        }
        .windowResizability(.contentSize)
    }
}

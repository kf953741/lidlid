import AppKit
import SwiftUI
import ServiceManagement
import LidLidServiceProtocol
import LidOnceSystem

final class ComponentModel: ObservableObject {
    @Published var busy = false
    @Published var ready = false
    @Published var state = SMAppService.Status.notRegistered
    @Published var message = ""
    @Published var language: AppLanguage = .system
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

import LidOnceCore
@main
struct CompatibilityApp: App {
    @StateObject private var model = ComponentModel()
    var body: some Scene {
        WindowGroup("LidLid Compatibility") {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Image(systemName: "moon.zzz.fill").font(.system(size: 30)).foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.text("盖盖兼容组件")).font(.title2.weight(.semibold))
                        Text(model.text("让合盖运行更可靠")).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Language", selection: $model.language) {
                        Text("系统 / System").tag(AppLanguage.system)
                        Text("中文").tag(AppLanguage.simplifiedChinese)
                        Text("English").tag(AppLanguage.english)
                    }.labelsHidden().frame(width: 120)
                }
                Text(model.text("免费组件，由你在 macOS 中授权。仅在盖盖会话期间管理系统睡眠；开盖、退出或连接超时后恢复原设置。"))
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(model.text(model.ready ? "兼容组件已就绪" : model.state == .enabled ? "正在连接兼容服务…" : model.state == .requiresApproval
                                         ? "请在系统设置中允许盖盖兼容组件" : "请先安装并授权盖盖兼容组件"),
                              systemImage: model.ready ? "checkmark.circle.fill" : "person.badge.key")
                        if !model.message.isEmpty {
                            Text(model.text(model.message)).font(.callout).foregroundStyle(.secondary)
                                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
                HStack {
                    if !model.inApplications {
                        Button(model.text("打开应用程序文件夹")) { NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications")) }
                    } else if !model.installed {
                        Button(model.text("安装兼容服务")) { model.install() }.buttonStyle(.borderedProminent)
                    } else if model.state == .requiresApproval {
                        Button(model.text("打开系统设置")) { SMAppService.openSystemSettingsLoginItems() }.buttonStyle(.borderedProminent)
                    }
                    Button(model.text("刷新状态")) { model.refresh() }
                    Spacer()
                    if model.state == .enabled {
                        Button(model.text("恢复睡眠并移除服务")) { model.remove() }
                    }
                }.disabled(model.busy)
                Text(model.text("需要主动睡眠时，请先关闭盖盖。移除组件前，请先点“恢复睡眠并移除服务”。"))
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(28).frame(width: 570).onAppear { model.refresh() }
        }.windowResizability(.contentSize)
    }
}

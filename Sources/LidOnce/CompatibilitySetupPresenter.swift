import AppKit
import SwiftUI
import LidOnceCore
import Combine

final class CompatibilitySetupPresenter: NSObject, NSWindowDelegate {
    var willPresent: (() -> Void)?
    var didDismiss: (() -> Void)?
    private var window: NSWindow?
    private static let size = NSSize(width: 484, height: 264)

    func show(model: AppModel) {
        precondition(Thread.isMainThread)
        if activateIfPresented() { return }
        let screen = NSApp.keyWindow?.screen ?? NSScreen.main
        willPresent?()
        let size = Self.size
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = model.text("合盖功能设置")
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: CompatibilitySetupView(model: model) { [weak self] in
            model.options = false
            self?.window?.close()
        })
        self.window = window
        window.center()
        if let screen {
            let visible = screen.visibleFrame, size = window.frame.size
            window.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func activateIfPresented() -> Bool {
        guard let window else { return false }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return true
    }

    func windowWillClose(_ notification: Notification) {
        window?.contentViewController = nil
        window = nil
        didDismiss?()
    }
}

private struct CompatibilitySetupView: View {
    @ObservedObject var model: AppModel
    let done: () -> Void
    @State private var installedURL: URL?
    @State private var downloadRequested = false
    @State private var launchFailed = false
    @State private var componentOpened = false
    private let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    // A user click hands this fixed, official download to the system browser.
    // The sandboxed app does not fetch, mount, copy, install or execute it.
    private let download = URL(string: "https://lidlid.vercel.app/downloads/LidLid-Compatibility-1.0.1-macOS-arm64.dmg")!

    private var ready: Bool { model.state.compatibilityReady }

    private enum Stage: Equatable {
        case download, moveToApplications, approve, ready
    }

    private var stage: Stage {
        if ready { return .ready }
        if installedURL != nil { return .approve }
        return downloadRequested ? .moveToApplications : .download
    }

    private var stageContent: (heading: String, detail: String, icon: String) {
        switch stage {
        case .download:
            return ("下载免费组件", "下载完成后，把组件拖入「应用程序」。", "arrow.down.to.line")
        case .moveToApplications:
            return ("拖入「应用程序」", "从浏览器下载列表打开 DMG，将 LidLid Compatibility 拖入「应用程序」。",
                    "folder.badge.plus")
        case .approve:
            return ("打开组件查看状态", componentOpened
                    ? "若 macOS 要求允许后台服务，请在组件窗口点「打开系统设置」。连接后会自动显示就绪。"
                    : "在组件窗口选择「安装兼容服务」，按 macOS 提示操作。",
                    "person.badge.key")
        case .ready:
            let detail: String
            switch model.closedLidAction {
            case .tryFree: detail = "试用到期不会自动扣费。"
            case .unlock: detail = "返回盖盖，永久解锁后即可开启合盖功能。"
            case .checking: detail = "返回盖盖，查看试用或购买状态。"
            default: detail = "返回盖盖，使用「合盖不休眠」。"
            }
            return ("兼容组件已就绪", detail, "checkmark.circle.fill")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 46, height: 46)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.text(ready ? "合盖准备已完成" : "设置合盖功能"))
                        .font(.system(size: 20, weight: .semibold))
                    Text(model.text(ready ? "免费组件已连接。" : "首次使用需安装免费兼容组件。"))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            ScrollView {
                let content = stageContent
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: content.icon).foregroundStyle(ready ? .green : .blue)
                            .accessibilityHidden(true)
                        Text(model.text(content.heading))
                            .font(.system(size: 14, weight: .semibold))
                            .accessibilityIdentifier("compatibility-setup-state")
                    }
                    Text(model.text(content.detail))
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if launchFailed {
                        Text(model.text("无法打开，请使用下方安装帮助。"))
                            .font(.footnote).foregroundStyle(.orange)
                    } else if stage == .approve,
                              model.state.compatibilityMessage != Snapshot().compatibilityMessage {
                        Text(model.text(model.state.compatibilityMessage))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(ready ? Color.green.opacity(0.08) : Color.primary.opacity(0.045),
                            in: RoundedRectangle(cornerRadius: 12))
            }
            .scrollBounceBehavior(.basedOnSize)
            HStack(spacing: 12) {
                primaryAction
                if stage == .moveToApplications {
                    Button(model.text("重新下载"), action: downloadComponent).buttonStyle(.link)
                }
                if ready, let installedURL {
                    Button(model.text("管理组件")) { openComponent(at: installedURL) }
                        .accessibilityIdentifier("compatibility-open")
                }
                Spacer(minLength: 0)
                Link(model.text("组件帮助"), destination: URL(string: model.language.resolved() == .simplifiedChinese
                    ? "https://lidlid.vercel.app/support/#compatibility" : "https://lidlid.vercel.app/en/support/#compatibility")!)
            }
        }
        .padding(22).frame(width: 484, height: 264, alignment: .topLeading)
        .tint(.blue).environment(\.locale, model.language.locale)
        .onAppear(perform: findInstalledComponent)
        .onReceive(refresh) { _ in findInstalledComponent() }
        .onChange(of: ready) { _, isReady in
            if isReady { launchFailed = false; downloadRequested = false; componentOpened = false }
        }
    }

    @ViewBuilder private var primaryAction: some View {
        switch stage {
        case .download:
            Button(model.text("下载免费组件"), action: downloadComponent)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("compatibility-download")
        case .moveToApplications:
            Button(model.text("打开下载文件夹")) {
                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                launchFailed = downloads.map { !NSWorkspace.shared.open($0) } ?? true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("compatibility-download-folder")
        case .approve:
            if let installedURL {
                Button(model.text("打开兼容组件")) { openComponent(at: installedURL) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("compatibility-open")
            }
        case .ready:
            if model.store.isStoreEdition, model.store.canStartTrial(compatibilityReady: ready) {
                Button(model.text("开始 7 天免费试用")) {
                    guard model.store.canStartTrial(compatibilityReady: ready) else { return }
                    done()
                    model.store.startTrial(compatibilityReady: ready)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("start-store-trial")
            } else {
                Button(model.text("返回盖盖"), action: done)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("compatibility-setup-done")
            }
        }
    }

    private func openComponent(at url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                componentOpened = !ready && error == nil
                launchFailed = error != nil
            }
        }
    }

    private func findInstalledComponent() {
        installedURL = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: "dev.kf.lidonce.compatibility")
            .first { $0.deletingLastPathComponent().path == "/Applications" }
    }

    private func downloadComponent() {
        componentOpened = false
        let opened = NSWorkspace.shared.open(download)
        if opened { downloadRequested = true }
        launchFailed = !opened
    }
}

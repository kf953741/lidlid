import AppKit
import SwiftUI
import LidOnceCore
import Combine

final class CompatibilitySetupPresenter: NSObject, NSWindowDelegate {
    var willPresent: (() -> Void)?
    var didDismiss: (() -> Void)?
    private var window: NSWindow?
    private var readiness: AnyCancellable?

    private static func contentSize(ready: Bool) -> NSSize {
        NSSize(width: 576, height: ready ? 440 : 650)
    }

    func show(model: AppModel) {
        precondition(Thread.isMainThread)
        if activateIfPresented() { return }
        let screen = NSApp.keyWindow?.screen ?? NSScreen.main
        willPresent?()
        let size = Self.contentSize(ready: model.state.compatibilityReady)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = model.text("合盖功能设置")
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: CompatibilitySetupView(model: model) { [weak self] in
            self?.window?.close()
        })
        self.window = window
        readiness = model.$state.map(\.compatibilityReady).removeDuplicates().dropFirst()
            .receive(on: RunLoop.main).sink { [weak self] ready in
                guard let window = self?.window else { return }
                let content = Self.contentSize(ready: ready)
                var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: content))
                frame.origin = NSPoint(x: window.frame.midX - frame.width / 2,
                                       y: window.frame.maxY - frame.height)
                window.setFrame(frame, display: true)
            }
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
        readiness = nil
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
    private let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    // A user click hands this fixed, official download to the system browser.
    // The sandboxed app does not fetch, mount, copy, install or execute it.
    private let download = URL(string: "https://lidlid.vercel.app/downloads/LidLid-Compatibility-1.0.1-macOS-arm64.dmg")!

    private var ready: Bool { model.state.compatibilityReady }

    private var nextStep: String {
        guard model.store.isStoreEdition else { return "返回盖盖，开启「本次合盖不休眠」。" }
        switch model.store.access {
        case .locked: return "返回盖盖，领取 7 天免费试用后，即可开启合盖功能。"
        case .expired: return "返回盖盖，永久解锁后，即可再次开启合盖功能。"
        case .loading: return "返回盖盖，查看试用或购买状态。"
        case .trial, .lifetime: return "返回盖盖，开启「本次合盖不休眠」。"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.text(ready ? "合盖准备已完成" : "设置合盖不休眠"))
                        .font(.system(size: 23, weight: .semibold))
                    Text(model.text(ready ? "免费组件已连接，无需再次安装或授权。"
                                    : "不插电、不接外接屏，也能让任务在合盖后继续运行。"))
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !ready {
                        Text(model.text("免费组件仅在你开启合盖功能时管理系统睡眠，结束后恢复原设置。首次安装需 macOS 管理员授权；开盖不休眠无需安装。"))
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: 17) {
                            step(1, "下载免费组件", "点下方按钮，在浏览器下载盖盖的官方安装包。")
                            step(2, "拖入「应用程序」", "打开下载的 DMG，将 LidLid Compatibility 拖入「应用程序」。")
                            step(3, "完成系统授权", "打开 LidLid Compatibility，点「安装兼容服务」，按 macOS 提示授权。系统可能要求 Touch ID 或管理员密码。")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: ready ? "checkmark.circle.fill" : "clock")
                            .foregroundStyle(ready ? Color.green : Color.blue)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(model.text(ready ? "兼容组件已就绪" : installedURL == nil ? "等待安装组件" : "已安装，等待连接"))
                                .font(.callout.weight(.semibold))
                                .accessibilityIdentifier("compatibility-setup-state")
                            Text(model.text(ready ? nextStep : installedURL == nil
                                            ? "安装并授权后，这里会自动更新，无需重启盖盖。"
                                            : model.state.compatibilityMessage))
                                .font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(ready ? 18 : 0)
                    .background(ready ? Color.green.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 14))
                    if ready {
                        Text(model.text("组件就绪不会自动开启合盖功能。每次合盖前，请先打开盖盖中的合盖开关。"))
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if launchFailed {
                        Text(model.text("无法打开，请使用下方安装帮助。"))
                            .font(.footnote).foregroundStyle(.secondary)
                    } else if downloadRequested && !ready {
                        Text(model.text("下载已交给浏览器，请打开 DMG 并拖入应用程序。"))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            HStack {
                if ready {
                    Button(model.text("返回盖盖"), action: done).buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("compatibility-setup-done")
                } else if installedURL == nil {
                    Button(model.text("下载免费组件"), action: downloadComponent).buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("compatibility-download")
                }
                if let installedURL {
                    Button(model.text(ready ? "管理组件" : "打开组件并授权")) {
                        NSWorkspace.shared.openApplication(at: installedURL, configuration: .init()) { _, error in
                            DispatchQueue.main.async { launchFailed = error != nil }
                        }
                    }.accessibilityIdentifier("compatibility-open")
                }
                Spacer()
                Link(model.text("组件帮助"), destination: URL(string: model.language.resolved() == .simplifiedChinese
                    ? "https://lidlid.vercel.app/support/#compatibility" : "https://lidlid.vercel.app/en/support/#compatibility")!)
            }
        }
        .padding(28).frame(width: 576, height: ready ? 440 : 650, alignment: .topLeading)
        .tint(.blue).environment(\.locale, model.language.locale)
        .onAppear(perform: findInstalledComponent)
        .onReceive(refresh) { _ in findInstalledComponent() }
        .onChange(of: ready) { _, isReady in
            if isReady { launchFailed = false; downloadRequested = false }
        }
    }

    private func step(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.blue).frame(width: 24, height: 24)
                .background(.blue.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(model.text(title)).font(.callout.weight(.semibold))
                Text(model.text(detail)).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func findInstalledComponent() {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "dev.kf.lidonce.compatibility")
        // Ignore copies in build folders or a mounted DMG. Service Management
        // requires the independently installed application in /Applications.
        installedURL = url?.deletingLastPathComponent().path == "/Applications" ? url : nil
    }

    private func downloadComponent() {
        downloadRequested = NSWorkspace.shared.open(download)
        launchFailed = !downloadRequested
    }
}

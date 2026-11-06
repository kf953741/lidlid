import AppKit
import SwiftUI
import LidOnceCore
import Combine

final class CompatibilitySetupPresenter: NSObject, NSWindowDelegate {
    var willPresent: (() -> Void)?
    var didDismiss: (() -> Void)?
    private var window: NSWindow?

    func show(model: AppModel) {
        precondition(Thread.isMainThread)
        if activateIfPresented() { return }
        let screen = NSApp.keyWindow?.screen ?? NSScreen.main
        willPresent?()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 576, height: 620),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = model.text("设置免费兼容组件")
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: CompatibilitySetupView(model: model) { [weak self] in
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
    private let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    // A user click hands this fixed, official download to the system browser.
    // The sandboxed app does not fetch, mount, copy, install or execute it.
    private let download = URL(string: "https://github.com/kf953741/lidlid/releases/download/compatibility-v1.0.1/LidLid-Compatibility-1.0.1-macOS-arm64.dmg")!

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.text("合盖之前，准备一次")).font(.system(size: 23, weight: .semibold))
                    Text(model.text("免费组件，只需安装一次。开盖功能无需安装。"))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 17) {
                step(1, "下载免费组件", "点下方按钮，浏览器会直接下载官方 DMG。")
                step(2, "放入应用程序", "打开 DMG，将 LidLid Compatibility 拖入「应用程序」。")
                step(3, "打开组件并授权", "在组件中点「安装兼容服务」，按 macOS 提示确认。")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: model.state.compatibilityReady ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    .foregroundStyle(model.state.compatibilityReady ? Color.green : Color.blue)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.text(model.state.compatibilityReady ? "兼容组件已就绪" : "正在自动检测组件"))
                        .font(.callout.weight(.semibold))
                        .accessibilityIdentifier("compatibility-setup-state")
                    Text(model.text(model.state.compatibilityReady ? "已连接。返回盖盖，即可领取试用或开启合盖功能。"
                                    : installedURL == nil ? "完成安装与授权后，盖盖会自动识别，无需重新启动。"
                                    : "已找到组件。打开并完成系统授权后，这里会自动更新。"))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if launchFailed {
                Text(model.text("无法打开，请使用下方安装帮助。"))
                    .font(.footnote).foregroundStyle(.secondary)
            } else if downloadRequested {
                Text(model.text("下载已交给浏览器，请打开 DMG 并拖入应用程序。"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                if model.state.compatibilityReady {
                    Button(model.text("返回盖盖"), action: done).buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("compatibility-setup-done")
                } else if installedURL == nil {
                    Button(model.text("下载免费组件"), action: downloadComponent).buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("compatibility-download")
                }
                if let installedURL {
                    Button(model.text("打开组件并授权")) {
                        NSWorkspace.shared.openApplication(at: installedURL, configuration: .init()) { _, error in
                            DispatchQueue.main.async { launchFailed = error != nil }
                        }
                    }.accessibilityIdentifier("compatibility-open")
                }
                Spacer()
                Link(model.text("安装帮助"), destination: URL(string: model.language.resolved() == .simplifiedChinese
                    ? "https://lidlid.vercel.app/support/#compatibility" : "https://lidlid.vercel.app/en/support/#compatibility")!)
            }
        }
        .padding(28).frame(width: 576, height: 620, alignment: .topLeading)
        .tint(.blue).environment(\.locale, model.language.locale)
        .onAppear(perform: findInstalledComponent)
        .onReceive(refresh) { _ in findInstalledComponent() }
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

import AppKit
import LidOnceCore

/// A menu-bar popover is not a suitable anchor for Apple's payment sheet:
/// its top edge can place confirmation controls outside the visible screen.
/// Keep a normal, centered window alive for the entire StoreKit operation.
final class StoreConfirmationPresenter {
    var willPresent: (() -> Void)?
    var didDismiss: (() -> Void)?
    private var window: NSWindow?
    private var controller: NSWindowController?
    private var previousActivationPolicy: NSApplication.ActivationPolicy?

    @MainActor func show(title: String, price: String? = nil) async -> NSWindow {
        let screen = NSApp.keyWindow?.screen ?? NSScreen.main
        willPresent?()
        previousActivationPolicy = NSApp.activationPolicy()
        // A payment needs a fully activated app window, not an accessory
        // popover. Restore the menu-bar-only policy after StoreKit finishes.
        NSApp.setActivationPolicy(.regular)
        let text = AppText(language: AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .system)
        let frame = NSRect(x: 0, y: 0, width: 640, height: 560)
        let window = NSWindow(contentRect: frame,
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = text("盖盖") + " · App Store"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 72).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 72).isActive = true
        let heading = NSTextField(wrappingLabelWithString: text(title))
        heading.font = .systemFont(ofSize: 22, weight: .semibold)
        heading.alignment = .center
        let message = NSTextField(wrappingLabelWithString: text("请在 App Store 窗口中完成确认。"))
        message.textColor = .secondaryLabelColor
        message.alignment = .center
        let progress = NSProgressIndicator()
        progress.style = .spinning
        progress.controlSize = .small
        progress.startAnimation(nil)
        var views: [NSView] = [icon, heading]
        if let price {
            let label = NSTextField(labelWithString: price)
            label.font = .systemFont(ofSize: 17, weight: .medium)
            views.append(label)
        }
        views.append(contentsOf: [message, progress])
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let contentController = NSViewController()
        contentController.view = NSView(frame: frame)
        window.contentViewController = contentController
        let content = contentController.view
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            stack.widthAnchor.constraint(equalTo: content.widthAnchor, constant: -64)
        ])
        window.center()
        if let screen {
            let visible = screen.visibleFrame
            let size = window.frame.size
            window.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2,
                                          y: visible.midY - size.height / 2))
        }
        self.window = window
        let controller = NSWindowController(window: window)
        self.controller = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeMain()
        window.standardWindowButton(.closeButton)?.isEnabled = false
        window.displayIfNeeded()
        // Give AppKit a turn to commit the new activation policy and window
        // before asking the system to attach its purchase confirmation UI.
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                window.makeMain()
                continuation.resume()
            }
        }
        return window
    }

    // Called synchronously by the AppKit delegate's menu/reopen callbacks.
    func activateIfPresented() -> Bool {
        precondition(Thread.isMainThread)
        guard let window else { return false }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return true
    }

    @MainActor func dismiss() {
        controller?.close()
        window = nil
        controller = nil
        if let policy = previousActivationPolicy { NSApp.setActivationPolicy(policy) }
        previousActivationPolicy = nil
        didDismiss?()
    }
}

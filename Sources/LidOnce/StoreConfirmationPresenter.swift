import AppKit
import SwiftUI
import StoreKit
import LidOnceCore

/// A menu-bar popover is not a suitable anchor for Apple's payment sheet:
/// its top edge can place confirmation controls outside the visible screen.
/// Keep a normal, centered window alive for the entire StoreKit operation.
final class StoreConfirmationPresenter: NSObject, NSWindowDelegate {
    var willPresent: (() -> Void)?
    var didDismiss: (() -> Void)?
    private var window: NSWindow?
    private var controller: NSWindowController?
    private var previousActivationPolicy: NSApplication.ActivationPolicy?
    private var pendingPurchase: CheckedContinuation<Product.PurchaseResult, Error>?
    private var purchaseInFlight = false

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

    /// Start from an actual user action in Apple's StoreKit view. The menu
    /// popover only opens this window; it does not immediately launch payment
    /// while AppKit is still activating the new window.
    @MainActor func purchase(_ product: Product, title: String) async throws -> Product.PurchaseResult {
        let window = await show(title: title, price: product.displayPrice)
        let text = AppText(language: AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .system)
        return try await withCheckedThrowingContinuation { continuation in
            pendingPurchase = continuation
            purchaseInFlight = false
            window.delegate = self
            window.standardWindowButton(.closeButton)?.isEnabled = true
            window.contentViewController = NSHostingController(rootView: StoreProductConfirmationView(
                product: product, text: text,
                started: { [weak self] in
                    self?.purchaseInFlight = true
                    self?.window?.standardWindowButton(.closeButton)?.isEnabled = false
                },
                completed: { [weak self] result in self?.finishPurchase(result) },
                cancel: { [weak self] in self?.finishPurchase(.success(.userCancelled)) }
            ))
        }
    }

    @MainActor private func finishPurchase(_ result: Result<Product.PurchaseResult, Error>) {
        guard let continuation = pendingPurchase else { return }
        pendingPurchase = nil
        purchaseInFlight = false
        continuation.resume(with: result)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !purchaseInFlight else { return false }
        finishPurchase(.success(.userCancelled))
        // The waiting task closes the window and restores the menu-bar policy.
        return false
    }

    func windowWillClose(_ notification: Notification) {
        finishPurchase(.success(.userCancelled))
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
        finishPurchase(.success(.userCancelled))
        window?.delegate = nil
        controller?.close()
        window = nil
        controller = nil
        if let policy = previousActivationPolicy { NSApp.setActivationPolicy(policy) }
        previousActivationPolicy = nil
        didDismiss?()
    }
}

private struct StoreProductConfirmationView: View {
    let product: Product
    let text: AppText
    let started: @MainActor () -> Void
    let completed: @MainActor (Result<Product.PurchaseResult, Error>) -> Void
    let cancel: @MainActor () -> Void
    @State private var purchasing = false

    var body: some View {
        VStack(spacing: 24) {
            ScrollView {
                VStack(spacing: 24) {
                    ProductView(product) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable().frame(width: 80, height: 80)
                    }
                    .productViewStyle(StorePurchaseProductStyle(text: text, purchasing: purchasing))
                    Text(text(product.id == StoreProducts.trial
                        ? "合盖试用 7 天。到期仅限制新会话，已开启的本次会话按原设置结束。永久版一次购买，不自动续费。合盖功能需免费兼容组件。"
                        : "一次购买，永久解锁合盖功能，不自动续费。开盖不休眠永久免费；合盖功能需免费兼容组件。"))
                        .font(.callout).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            Button(text("暂不购买"), action: cancel)
                .disabled(purchasing)
                .accessibilityIdentifier("cancel-store-confirmation")
        }
        .padding(40).frame(width: 640, height: 560)
        .environment(\.locale, text.language.locale)
        .onInAppPurchaseStart { _ in
            await MainActor.run { purchasing = true; started() }
        }
        .onInAppPurchaseCompletion { _, result in completed(result) }
    }
}

/// Keep StoreKit's purchase action and presentation context, while making the
/// call to action readable as a purchase rather than a standalone price link.
private struct StorePurchaseProductStyle: ProductViewStyle {
    let text: AppText
    let purchasing: Bool

    func makeBody(configuration: Configuration) -> some View {
        if let product = configuration.product {
            let trial = product.id == StoreProducts.trial
            StorePurchaseOffer(
                title: text(trial ? "免费试用合盖 7 天" : "合盖永久解锁"),
                detail: text(trial ? "免费试用，不会自动扣费。" : "一次购买，不自动续费。"),
                buttonTitle: trial ? text("开始 7 天免费试用")
                    : text("购买并永久解锁 · ") + product.displayPrice,
                purchasedTitle: text("已购买"),
                purchased: configuration.hasCurrentEntitlement,
                purchasing: purchasing,
                icon: configuration.icon,
                purchase: { configuration.purchase() }
            )
        } else {
            ProductView(configuration).productViewStyle(.large)
        }
    }
}

struct StorePurchaseOffer<Icon: View>: View {
    let title: String
    let detail: String
    let buttonTitle: String
    let purchasedTitle: String
    let purchased: Bool
    let purchasing: Bool
    let icon: Icon
    let purchase: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            icon
            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.callout).foregroundStyle(.secondary)
            Button(action: purchase) {
                HStack(spacing: 8) {
                    if purchasing {
                        ProgressView().controlSize(.small)
                    } else if purchased {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(purchased ? purchasedTitle : buttonTitle)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(purchasing || purchased)
            .accessibilityIdentifier("confirm-store-purchase")
        }
        .frame(maxWidth: .infinity)
    }
}

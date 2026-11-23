import AppKit
import Foundation
import StoreKit
import Combine
import LidOnceCore

/// StoreKit runs only in the explicitly packaged App Store edition. The
/// existing open-source distribution never prompts for an Apple purchase.
final class StoreAccessManager: ObservableObject {
    let isStoreEdition = Bundle.main.object(forInfoDictionaryKey: "LidLidDistribution") as? String == "app-store"
    @Published private(set) var access: StoreAccess = .loading
    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var working = false
    @Published private(set) var message: String?
    let confirmation = StoreConfirmationPresenter()
    private var records: [String: StorePurchase] = [:]
    private var updates: Task<Void, Never>?
    private var startup: Task<Void, Never>?
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var started = false
    private let clockEpoch = ContinuousClock.now
    private var clock = StoreAccessClock(wallTime: Date(),
        lastObserved: UserDefaults.standard.object(forKey: "storeLastObservedDate") as? Date,
        uptime: 0)

    private func continuousElapsed() -> TimeInterval {
        let c = clockEpoch.duration(to: .now).components
        return Double(c.seconds) + Double(c.attoseconds) / 1e18
    }

    var allowsStartingClosedLidSession: Bool { permits(Command("arm")) }
    func permits(_ command: Command) -> Bool {
        access.permits(command, inStoreEdition: isStoreEdition, at: currentDate)
    }
    var canPurchaseTrial: Bool { !working && products[StoreProducts.trial] != nil }
    var canPurchaseLifetime: Bool { !working && products[StoreProducts.lifetime] != nil }
    var canPurchase: Bool { canPurchaseLifetime }
    var hasMissingProducts: Bool { products.count < StoreProducts.all.count }
    var lifetimePrice: String? { products[StoreProducts.lifetime]?.displayPrice }
    private var currentDate: Date { clock.now(wallTime: Date(), uptime: continuousElapsed()) }

    deinit {
        updates?.cancel(); startup?.cancel(); timer?.invalidate()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }

    func start() {
        guard isStoreEdition && !started else { return }
        started = true
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.recompute()
        }
        updates = Task { @MainActor [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled, let self else { return }
                if case .verified(let transaction) = result, self.accept(transaction) {
                    self.recompute()
                    await transaction.finish()
                } else if case .unverified = result {
                    self.message = "无法验证购买，请恢复购买或稍后重试。"
                }
            }
        }
        startup = Task { @MainActor [weak self] in
            guard let self else { return }
            self.working = true
            await self.refreshEntitlements()
            self.working = false
            await self.loadProducts(preserveMessage: true)
        }
    }

    func retry() {
        guard isStoreEdition && !working else { return }
        Task { @MainActor [weak self] in await self?.loadProducts() }
    }

    func canStartTrial(compatibilityReady: Bool) -> Bool {
        isStoreEdition && canPurchaseTrial && access.permitsStartingTrial(compatibilityReady: compatibilityReady)
    }

    func startTrial(compatibilityReady: Bool) {
        guard canStartTrial(compatibilityReady: compatibilityReady) else { return }
        purchase(StoreProducts.trial)
    }

    func purchaseLifetime() { purchase(StoreProducts.lifetime) }

    private func purchase(_ productID: String) {
        guard isStoreEdition, !working, let product = products[productID] else { return }
        working = true; message = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            let title = productID == StoreProducts.trial ? "免费试用合盖 7 天" : "合盖永久解锁"
            defer { self.working = false; self.confirmation.dismiss() }
            do {
                let result = try await self.confirmation.purchase(product, title: title)
                switch result {
                case .success(let result):
                    guard case .verified(let transaction) = result, self.accept(transaction) else {
                        self.message = "无法验证购买，请恢复购买或稍后重试。"; return
                    }
                    self.recompute()
                    await transaction.finish()
                case .pending: self.message = "购买正在等待批准，完成后将自动解锁。"
                case .userCancelled: break
                @unknown default: self.message = "购买未完成，请稍后重试。"
                }
            } catch { self.message = "无法完成购买，请检查 App Store 连接后重试。" }
        }
    }

    func restore() {
        guard isStoreEdition && !working else { return }
        working = true; message = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.confirmation.show(title: "恢复购买")
            defer { self.working = false; self.confirmation.dismiss() }
            do {
                try await AppStore.sync()
                await self.refreshEntitlements()
                if !self.allowsStartingClosedLidSession { self.message = "没有可恢复的有效购买；已结束的试用不会重新开始。" }
            } catch { self.message = "无法恢复购买，请检查 App Store 连接后重试。" }
        }
    }

    @MainActor private func loadProducts(preserveMessage: Bool = false) async {
        guard !working else { return }
        working = true
        if !preserveMessage { message = nil }
        defer { working = false }
        do {
            let loaded = try await Product.products(for: StoreProducts.all)
            // The trial must be free, and the permanent unlock must never be
            // an auto-renewing subscription or consumable product.
            products = Dictionary(uniqueKeysWithValues: loaded.filter {
                $0.type == .nonConsumable && ($0.id != StoreProducts.trial || $0.price == 0)
            }.map { ($0.id, $0) })
            if products.count != StoreProducts.all.count, message == nil {
                message = "商店商品暂不可用，请稍后重试。"
            }
        } catch {
            if message == nil { message = "商店商品暂不可用，请稍后重试。" }
        }
    }

    @MainActor private func refreshEntitlements() async {
        records = [:]
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result { _ = accept(transaction) }
            else { message = "无法验证购买，请恢复购买或稍后重试。" }
        }
        recompute()
    }

    private func accept(_ transaction: Transaction) -> Bool {
        guard StoreProducts.all.contains(transaction.productID), transaction.productType == .nonConsumable else { return false }
        let incoming = StorePurchase(productID: transaction.productID,
            originalPurchaseDate: transaction.originalPurchaseDate, revoked: transaction.revocationDate != nil)
        if let existing = records[transaction.productID], !existing.revoked, !incoming.revoked {
            records[transaction.productID] = StorePurchase(
                productID: transaction.productID,
                originalPurchaseDate: min(existing.originalPurchaseDate, incoming.originalPurchaseDate),
                revoked: false
            )
        } else {
            records[transaction.productID] = incoming
        }
        return true
    }

    private func recompute() {
        guard isStoreEdition else { return }
        let now = currentDate
        // Persist at most once per minute using the jump-guarded date; never save an unverified entitlement.
        let persistable = clock.persistableDate
        let previous = UserDefaults.standard.object(forKey: "storeLastObservedDate") as? Date ?? .distantPast
        if persistable.timeIntervalSince(previous) >= 60 {
            UserDefaults.standard.set(persistable, forKey: "storeLastObservedDate")
        }
        let next = StoreAccess.evaluate(Array(records.values), now: now)
        if access != next { access = next }
        syncTrialTimer(now: now)
    }

    private func syncTrialTimer(now: Date) {
        timer?.invalidate()
        timer = nil
        guard case .trial(let deadline) = access else { return }
        let remaining = max(0, deadline.timeIntervalSince(now))
        let delay = remaining <= 60 ? max(1, remaining) : min(60, remaining - 30)
        let nextTick = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.recompute()
        }
        nextTick.tolerance = delay >= 30 ? 5 : 0.2
        RunLoop.main.add(nextTick, forMode: .common)
        timer = nextTick
    }
}

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
    private var records: [String: StorePurchase] = [:]
    private var updates: Task<Void, Never>?
    private var startup: Task<Void, Never>?
    private var timer: Timer?
    private var started = false
    private var clock = StoreAccessClock(wallTime: Date(),
        lastObserved: UserDefaults.standard.object(forKey: "storeLastObservedDate") as? Date,
        uptime: ProcessInfo.processInfo.systemUptime)

    var allowsKeepAwake: Bool { !isStoreEdition || access.permitsKeepAwake(at: currentDate) }
    var canPurchase: Bool { !working && products[StoreProducts.trial] != nil && products[StoreProducts.lifetime] != nil }
    var lifetimePrice: String? { products[StoreProducts.lifetime]?.displayPrice }
    private var currentDate: Date { clock.now(wallTime: Date(), uptime: ProcessInfo.processInfo.systemUptime) }

    deinit { updates?.cancel(); startup?.cancel(); timer?.invalidate() }

    func start() {
        guard isStoreEdition && !started else { return }
        started = true
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
            await self.refreshEntitlements()
            await self.loadProducts()
        }
        let tick = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, case .trial = self.access else { return }
            self.recompute()
        }
        RunLoop.main.add(tick, forMode: .common); timer = tick
    }

    func retry() {
        guard isStoreEdition && !working else { return }
        Task { @MainActor [weak self] in await self?.loadProducts() }
    }

    func purchase(_ productID: String) {
        guard isStoreEdition && canPurchase, let product = products[productID] else { return }
        working = true; message = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.working = false }
            do {
                switch try await product.purchase() {
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
            defer { self.working = false }
            do {
                try await AppStore.sync()
                await self.refreshEntitlements()
                if !self.allowsKeepAwake { self.message = "没有可恢复的有效购买；已结束的试用不会重新开始。" }
            } catch { self.message = "无法恢复购买，请检查 App Store 连接后重试。" }
        }
    }

    @MainActor private func loadProducts() async {
        guard !working else { return }
        working = true; message = nil
        defer { working = false }
        do {
            let loaded = try await Product.products(for: StoreProducts.all)
            // The trial must be free, and the permanent unlock must never be
            // an auto-renewing subscription or consumable product.
            products = Dictionary(uniqueKeysWithValues: loaded.filter {
                $0.type == .nonConsumable && ($0.id != StoreProducts.trial || $0.price == 0)
            }.map { ($0.id, $0) })
            if products.count != StoreProducts.all.count { message = "商店商品暂不可用，请稍后重试。" }
        } catch { message = "商店商品暂不可用，请稍后重试。" }
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
        records[transaction.productID] = StorePurchase(productID: transaction.productID,
            originalPurchaseDate: transaction.originalPurchaseDate, revoked: transaction.revocationDate != nil)
        return true
    }

    private func recompute() {
        guard isStoreEdition else { return }
        let now = currentDate
        // Persist at most once per minute; never save an unverified entitlement.
        let previous = UserDefaults.standard.object(forKey: "storeLastObservedDate") as? Date ?? .distantPast
        if now.timeIntervalSince(previous) >= 60 { UserDefaults.standard.set(now, forKey: "storeLastObservedDate") }
        let next = StoreAccess.evaluate(Array(records.values), now: now)
        if access != next { access = next }
    }
}

import SwiftUI
import LidOnceCore

struct StoreAccessView: View {
    @ObservedObject var store: StoreAccessManager
    let text: AppText

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch store.access {
            case .lifetime:
                Label(text("永久版已解锁"), systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .medium))
            case .loading:
                Text(text("正在检查购买…")).font(.system(size: 12))
            case .trial(let deadline):
                Text(text("试用至：") + deadline.formatted(.dateTime.year().month(.abbreviated).day().hour().minute().locale(text.language.locale)))
                    .font(.system(size: 12, weight: .medium))
            case .expired:
                Text(text("7 天试用已结束")).font(.system(size: 14, weight: .medium))
            case .locked:
                Text(text("先试用，再决定")).font(.system(size: 14, weight: .medium))
            }
            if store.access != .lifetime {
                Text(text("试用结束后，合盖与开盖防休眠将关闭。永久版一次购买，不自动续费。完整合盖功能另需免费兼容组件。"))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if store.access == .locked {
                    Button(text("免费试用 7 天")) { store.purchase(StoreProducts.trial) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!store.canPurchase)
                        .accessibilityIdentifier("start-store-trial")
                }
                Button {
                    store.purchase(StoreProducts.lifetime)
                } label: {
                    if let price = store.lifetimePrice {
                        Text(text("永久解锁 · ") + price)
                    } else {
                        Text(text("正在加载永久版价格…"))
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!store.canPurchase)
                .accessibilityIdentifier("buy-store-lifetime")
            }
            HStack(spacing: 14) {
                Button(text("恢复购买"), action: store.restore)
                    .disabled(store.working)
                    .accessibilityIdentifier("restore-store-purchases")
                if store.lifetimePrice == nil {
                    Button(text("重新加载商品"), action: store.retry).disabled(store.working)
                }
                if store.working { ProgressView().controlSize(.small) }
            }
            .buttonStyle(.link).font(.system(size: 11))
            if let message = store.message {
                Text(text(message)).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

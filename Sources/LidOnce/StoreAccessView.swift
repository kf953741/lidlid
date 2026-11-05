import SwiftUI
import LidOnceCore

struct StoreAccessView: View {
    @ObservedObject var store: StoreAccessManager
    let text: AppText
    let compatibilityReady: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text("开盖不休眠永久免费")).font(.system(size: 11)).foregroundStyle(.secondary)
            switch store.access {
            case .lifetime:
                Label(text("合盖永久版已解锁"), systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .medium))
            case .loading:
                Text(text("正在检查购买…")).font(.system(size: 12))
            case .trial(let deadline):
                Text(text("合盖试用至：") + deadline.formatted(.dateTime.year().month(.abbreviated).day().hour().minute().locale(text.language.locale)))
                    .font(.system(size: 12, weight: .medium))
            case .expired:
                Text(text("合盖试用已结束")).font(.system(size: 14, weight: .medium))
            case .locked:
                Text(text("合盖先试用，再决定")).font(.system(size: 14, weight: .medium))
            }
            if store.access != .lifetime {
                Text(text("合盖试用 7 天。到期仅限制新会话，已开启的本次会话按原设置结束。永久版一次购买，不自动续费。合盖功能需免费兼容组件。"))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if store.access == .locked {
                    if !compatibilityReady {
                        Text(text("设置好免费兼容组件后，可开始合盖试用。"))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button(text("免费试用合盖 7 天")) { store.startTrial(compatibilityReady: compatibilityReady) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!store.canStartTrial(compatibilityReady: compatibilityReady))
                        .accessibilityIdentifier("start-store-trial")
                }
                Button {
                    store.purchaseLifetime()
                } label: {
                    if let price = store.lifetimePrice {
                        Text(text("永久解锁合盖 · ") + price)
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

import SwiftUI
import LidOnceCore

struct StoreAccessView: View {
    enum Surface { case panel, settings }

    @ObservedObject var store: StoreAccessManager
    let text: AppText
    let surface: Surface

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if case .trial(let deadline) = store.access {
                Text(text("合盖试用至：") + deadline.formatted(
                    Date.FormatStyle(date: .abbreviated, time: .shortened).locale(text.language.locale)
                ))
                .foregroundStyle(.secondary)
            }
            if surface == .settings, store.access == .lifetime {
                Label(text("合盖永久版已解锁"), systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button(text("恢复购买"), action: store.restore)
                    .disabled(store.working)
                    .accessibilityIdentifier("restore-store-purchases")
                Spacer(minLength: 0)
                if store.lifetimePrice == nil, store.access != .lifetime, !store.working {
                    Button(text("重新加载商品"), action: store.retry)
                }
                if surface == .settings, store.access != .lifetime, let price = store.lifetimePrice {
                    Button(text("永久解锁合盖 · ") + price, action: store.purchaseLifetime)
                        .disabled(!store.canPurchase)
                        .accessibilityIdentifier("settings-buy-store-lifetime")
                }
                if store.working { ProgressView().controlSize(.mini) }
            }
            .buttonStyle(.link)
            if let message = store.message {
                Text(text(message)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 4)
    }
}

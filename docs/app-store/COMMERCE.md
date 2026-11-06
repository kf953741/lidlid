# 商店版试用与永久解锁

商店版的 **开盖不休眠永久免费**。设置好免费兼容组件后，可主动领取 **7 天合盖功能试用**，随后可选择 **US$4.99 一次买断合盖功能**。不订阅，不自动扣费。其他商店货币使用 Apple 后台配置的当地价格，应用展示 StoreKit 返回的实际价格。

App Store Connect 商品字段在 [purchases.json](purchases.json)。两个商品都是非消耗型内购；试用必须是免费价格且英文名为 `7-day Trial`。免费试用购买日期由 Apple 已验证交易的 `originalPurchaseDate` 决定，恢复购买不会重置时间。永久版撤销或退款后按剩余试用判断权限；试用到期只限制新开启的合盖会话，已经开始的会话（含已开启、尚未合盖，以及已经合盖两种情况）继续按原时长、开盖结束及保护规则运行，不发送任何到期停止指令。手动结束后不能再次开启合盖模式，直到购买永久版。开盖功能不受购买、恢复、加载失败或试用到期影响。

试用开始前展示持续时间、到期后新会话的限制与当前会话的延续规则、永久解锁价格，以及完整合盖功能对免费兼容组件的依赖。用户可随时恢复购买。商品不可用、交易未通过 Apple 验证、购买等待批准时不解锁。

`LidLidDistribution=app-store` 明确启用 StoreKit 购买流程。普通开源构建保持免费；商店打包脚本强制启用购买流程，并校验真实发行证书、App Store 描述文件和沙盒。不会将开发签名包当作已可上传的发行包。

正式构建（配置发行证书、App ID 和描述文件之后）：

```sh
LIDLID_STORE_APP_IDENTITY='Apple Distribution: <name> (63ALH54858)' \
LIDLID_STORE_INSTALLER_IDENTITY='3rd Party Mac Developer Installer: <name> (63ALH54858)' \
LIDLID_STORE_PROFILE='/absolute/path/LidLid_AppStore.provisionprofile' \
zsh scripts/package-app-store.sh
```

实际团队若不同，先迁移并实测签名固定的 XPC 与 App Group，不能只替换签名。独立组件 1.0.1 已完成 Developer ID 签名、Apple 公证及正式 DMG 发布，详见 submission-status.json。

当前采用 macOS 专用的 `63ALH54858.dev.kf.lidonce` 组标识。Apple 通过签名团队前缀授权这类组，不要求在开发者后台注册，也不要求描述文件列出它；打包仍校验 App ID、团队、发行证书和描述文件有效期。只有使用跨平台的 `group.*` 标识时才需要对应描述文件授权。依据：[Apple 的 macOS App Group 说明](https://developer.apple.com/documentation/xcode/accessing-app-group-containers)。

正式商店记录、两个内购商品和发行包需由具备有效会员权限的开发者账户创建。价格地区、付费应用协议、税务/银行和审核联系人需在正式后台按实际情况完成。内部账户状态和个人资料只保存在本机，不提交公开仓库。

本地测试覆盖七天边界、原始日期恢复、撤销、永久权限、时钟回退和试用前的组件就绪条件。`zsh scripts/test-store-model.sh` 还会运行真实 AppModel 与模拟权益、管道工作进程，验证开盖始终免费、到期不发送停止或关闭开盖模式指令、心跳继续、用户手动结束后拒绝再次开启合盖；不调用系统电源 API。这些测试不替代 StoreKit 沙盒中的购买、取消、恢复、待批准、退款/撤销测试。两项商品已在 App Store Connect 配置，付费协议、银行与税表状态已就绪。2026-11-07 已从 Apple 商品目录及实际 TestFlight 界面加载免费试用和 CNY38 永久版；真实试用已领取，永久购买和恢复购买仍在验证。商店展示截图已更新为 1.6.1 构建 12 的真实控制区与选项页；完整购买界面另作内购审核截图，实际购买验收记录见 submission-status.json。

依据：[App Review 3.1.1](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)；[StoreKit Transaction](https://developer.apple.com/documentation/storekit/transaction)。

## 购买窗口

构建 13 将购买与恢复操作从菜单栏弹出面板移到居中的普通 NSWindow。macOS 15.2 及以上明确使用 `Product.purchase(confirmIn:options:)` 指定窗口；14.0–15.1 使用已激活的居中窗口配合旧 API。操作期间保留窗口，结束或取消后关闭，并回到菜单栏面板；再次点击菜单栏图标会激活当前确认窗口。此调整修复 Apple 购买控件被放到屏幕上方的问题。实际交易仍以 TestFlight 验证为准。

API 依据：[Apple Product.purchase(confirmIn:options:)](https://developer.apple.com/documentation/storekit/product/purchase(confirmin:options:)-8eai6)。

实际 TestFlight 14 已通过试用恢复与永久购买取消，原到期日未重置；永久购买面板仍缺确认控件，因此没有标记交易验收通过。构建 15 临时切换为普通应用激活策略，使用 NSWindowController 和内容控制器，并等 AppKit 完成窗口激活后再调用 StoreKit；真实购买结果仍待验证。

`python3 scripts/archive-app-store.py --organizer` 会从已验证的发行应用生成全新归档，纳入 UUID 匹配的主程序及工作进程 dSYM。它不会继承旧上传记录、覆盖既有归档、上传或打开 Xcode。

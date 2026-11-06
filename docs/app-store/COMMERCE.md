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

实际团队若不同，先迁移并实测签名固定的 XPC 与 App Group，不能只替换签名。兼容组件仍需另外完成 Developer ID 签名、公证与正式下载。

当前采用 macOS 专用的 `63ALH54858.dev.kf.lidonce` 组标识。Apple 通过签名团队前缀授权这类组，不要求在开发者后台注册，也不要求描述文件列出它；打包仍校验 App ID、团队、发行证书和描述文件有效期。只有使用跨平台的 `group.*` 标识时才需要对应描述文件授权。依据：[Apple 的 macOS App Group 说明](https://developer.apple.com/documentation/xcode/accessing-app-group-containers)。

正式商店记录、两个内购商品和发行包需由具备有效会员权限的开发者账户创建。价格地区、付费应用协议、税务/银行和审核联系人需在正式后台按实际情况完成。内部账户状态和个人资料只保存在本机，不提交公开仓库。

本地测试覆盖七天边界、原始日期恢复、撤销、永久权限、时钟回退和试用前的组件就绪条件。`zsh scripts/test-store-model.sh` 还会运行真实 AppModel 与模拟权益、管道工作进程，验证开盖始终免费、到期不发送停止或关闭开盖模式指令、心跳继续、用户手动结束后拒绝再次开启合盖；不调用系统电源 API。这些测试不替代 StoreKit 沙盒中的购买、取消、恢复、待批准、退款/撤销测试。两项商品已于 2026-11-06 在 App Store Connect 创建，实际购买测试仍待账户商务资料和商品同步就绪。商店展示截图已更新为 1.6.1 构建 12 的真实控制区与选项页；完整购买界面另作内购审核截图，实际购买流程仍需验证。

依据：[App Review 3.1.1](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)；[StoreKit Transaction](https://developer.apple.com/documentation/storekit/transaction)。

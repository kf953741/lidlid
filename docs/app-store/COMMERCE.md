# 商店版试用与永久解锁

商店版免费下载，主动领取 **7 天免费试用**，随后可选择 **US$4.99 一次买断**。不订阅，不自动扣费。其他商店货币使用 Apple 后台配置的当地价格，应用展示 StoreKit 返回的实际价格。

App Store Connect 商品字段在 [purchases.json](purchases.json)。两个商品都是非消耗型内购；试用必须是免费价格且英文名为 `7-day Trial`。免费试用购买日期由 Apple 已验证交易的 `originalPurchaseDate` 决定，恢复购买不会重置时间。永久版撤销或退款后按剩余试用判断权限；试用到期将关闭两种防休眠模式，恢复正常睡眠。

试用开始前展示持续时间、到期后关闭的功能、永久解锁价格，以及完整合盖功能对免费兼容组件的依赖。用户可随时恢复购买。商品不可用、交易未通过 Apple 验证、购买等待批准时不解锁。

`LidLidDistribution=app-store` 明确启用 StoreKit 购买流程。普通开源构建保持免费；商店打包脚本强制启用购买流程，并校验真实发行证书、App Store 描述文件和沙盒。不会将开发签名包当作已可上传的发行包。

正式构建（激活会员并配置证书、App ID、App Group 和描述文件之后）：

```sh
LIDLID_STORE_APP_IDENTITY='Apple Distribution: <name> (63ALH54858)' \
LIDLID_STORE_INSTALLER_IDENTITY='3rd Party Mac Developer Installer: <name> (63ALH54858)' \
LIDLID_STORE_PROFILE='/absolute/path/LidLid_AppStore.provisionprofile' \
zsh scripts/package-app-store.sh
```

实际团队若不同，先迁移并实测签名固定的 XPC 与 App Group，不能只替换签名。兼容组件仍需另外完成 Developer ID 签名、公证与正式下载。

正式商店记录、两个内购商品和发行包需由具备有效会员权限的开发者账户创建。价格地区、付费应用协议、税务/银行和审核联系人需在正式后台按实际情况完成。内部账户状态和个人资料只保存在本机，不提交公开仓库。

本地测试覆盖七天边界、原始日期恢复、撤销、永久权限和时钟回退；这些测试不替代 StoreKit 沙盒中的购买、取消、恢复、待批准、退款/撤销测试。后者待会员激活后完成。现有商店截图未包含本次购买界面，送审前需更新。

依据：[App Review 3.1.1](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)；[StoreKit Transaction](https://developer.apple.com/documentation/storekit/transaction)。

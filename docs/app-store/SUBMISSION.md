# 盖盖 Mac App Store 送审记录

1.6.1 构建 18 已于 2026 年 11 月 7 日 15:39（上海时间）提交 Apple 审核，主应用、7 天试用和永久解锁三项均显示「等待审核」，刷新页面后已核对。公开发布保持手动，尚未上架。

采用「沙盒商店主应用＋独立免费兼容组件」。开盖永久免费；合盖主动领取 7 天试用，随后 US$4.99（中国大陆 ¥38）一次购买永久解锁。试用到期仅限制新会话，不打断已开启的任务。

[App Store Connect 送审详情](https://appstoreconnect.apple.com/apps/6831452648/distribution/reviewsubmissions/details/fbd3c532-4dc6-49cc-b1c8-2afdae6e0399)；提交 ID：`fbd3c532-4dc6-49cc-b1c8-2afdae6e0399`。

## 当前验证结果

- 实际 TestFlight 17：持有人完成永久购买，应用显示已验证的「合盖永久版已解锁」。没有覆盖本地权益或伪造收据。
- 试用领取、保留原到期时间及试用恢复已通过早前真实 TestFlight 测试；永久购买取消的三条路径已通过构建 17 测试。
- 永久版恢复：实际 TestFlight 17 和 18 均在持有人完成 Apple 认证后成功返回主界面，保留永久权益，无恢复错误。
- 构建 18 已通过 Xcode 上传、Apple 处理并从 TestFlight 安装；Beta 签名、收据及主程序／代理 UUID 与最终归档一致。
- 构建 18 将单独价格文字改为醒目的中英文蓝色购买按钮，显示 Apple 返回的当地价格，仍调用原生 ProductView 的 `configuration.purchase()`。共享界面的两种语言布局和点击使用明确标注的示例价格预览核对；该预览不作为真实交易或审核截图。已购买非消耗型商品，未在 18 重复购买。
- 本机编译、14 项现有权益／本地化测试、正式签名、描述文件、沙盒、隐私清单及安装包校验通过，dSYM 匹配。最终代码为 `c57edce2e8e468bfe9aaaa46cf5a826cbf34898f`，GitHub Actions 42351315968 成功。
- 免费组件 1.0.1 (2) 已正式签名、公证并发布，实际 TestFlight XPC 身份识别通过。导出应用及 DMG 内应用通过签名、公证票据、Gatekeeper 和远端 SHA256 回读。外层 DMG 没有单独公证任务。
- 本地购买按钮预览曾误用方形原图作为 Dock 图标，现改用正式应用相同的圆角 ICNS 并关闭预览。正式应用图标原本正确，此修正未改变已上传二进制。

完整状态以 [submission-status.json](submission-status.json) 为准。组件工程见 [COMPATIBILITY-ENGINEERING.md](../COMPATIBILITY-ENGINEERING.md)，用户设置说明见 [COMPATIBILITY.zh-CN.md](../COMPATIBILITY.zh-CN.md)。

## Apple 后台与素材

| 项目 | 状态 |
| --- | --- |
| 团队与应用 | 63ALH54858；dev.kf.lidonce；应用 6831452648；SKU LIDLID_MAC |
| 审核提交 | 1.6.1 (18)、`dev.kf.lidonce.lifetime`、`dev.kf.lidonce.trial7days` 同一提交；三项均等待审核，未完成草稿为 0 |
| 价格与地区 | 应用免费、零元 7 天试用、US$4.99／¥38 永久非消耗型内购；首发美国和中国大陆；无订阅、续费或自动扣费 |
| 联系人与商务 | 审核联系人已由持有人填写并通过校验；付费协议有效、银行可用、两份税表在使用。只记录状态，不公开私密资料 |
| 隐私 | 持有人已确认并发布「未收集数据」；中英文隐私政策与官网保持同源 |
| 商店文案 | 中英文名称、简介、推广语及关键词已保存并回读核对；保留 MacBook 合盖不休眠及 Codex／Claude Code 任务场景 |
| 公开图库 | 中文、英文各五张，后台各 5/10，价格海报已移除。控制区与选项页保持捕获构建 12 的外观，来源见 captures/manifest.json |
| 私有内购图片 | 两项商品保存的 2880×1800 真实图片来自 TestFlight 14 的主购买区，该主界面在 18 未改变。来源及独立蓝色购买按钮已在审核说明中明确；示例价格预览未上传 |
| 审核说明 | 最终主说明保存并回读一致，3938 字符；两项商品备注保存在 iap-review-notes.json。组件下载、设置及移除步骤已提供 |
| TestFlight | 仅含持有人一人的 Owner validation 组；已安装构建 18，永久权益及恢复验证通过，原有两个开关关闭状态和跟随系统语言设置保留 |

## 后续

等待 Apple 审核结果；如有审核问题，按具体反馈处理。审核通过后由持有人预览并确认公开发布时间，当前不自动发布。

公开客服与隐私邮箱：[kf953741@gmail.com](mailto:kf953741@gmail.com)。不提供 GitHub 反馈入口。正式支持网址为 https://lidlid.vercel.app/zh/support/ 和 https://lidlid.vercel.app/en/support/。

metadata/zh-Hans 和 metadata/en-US 可复制商店字段；screenshots 按 01–05 上传对应语言 PNG。review-notes.en.txt 用于 Apple 审核。submission-inputs.example.json 仅为空模板；真实审核联系人保存在本机或 Apple 后台，不放入公开仓库。

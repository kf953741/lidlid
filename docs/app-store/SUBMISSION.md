# 盖盖 Mac App Store 提交准备

当前代码为 1.6.1 构建 12，采用「沙盒商店主应用＋独立免费兼容组件」。商店版开盖永久免费，合盖功能试用 7 天后可 US$4.99 一次买断；到期仅限制新会话，本次会话按原设置结束，见 [COMMERCE.md](COMMERCE.md) 和 [purchases.json](purchases.json)。正式发行签名、版本上传和两项内购配置已完成；组件公证及下载、实际购买验证和持有人确认完成前不要提交。中英文商店截图均已更新为 1.6.1 构建 12 的真实主界面局部和完整选项页，并复用已确认的中英文出门场景及前后对比插画，见 captures/manifest.json；实际购买流程仍需验证。

组件架构与验证见 [COMPATIBILITY-ENGINEERING.md](../COMPATIBILITY-ENGINEERING.md)，面向用户的设置说明见 [COMPATIBILITY.zh-CN.md](../COMPATIBILITY.zh-CN.md)。所有完成状态以实际验证记录为准。

1.5.0 新增沙盒内独立的「开盖不休眠」开关，允许屏幕熄灭；此功能无需外部组件，完整合盖功能仍需组件。

## 可直接使用的资料

- metadata/zh-Hans 与 metadata/en-US 中的纯文本字段可逐项复制。
- screenshots 中按 01 至 05 的顺序上传对应语言 PNG；尺寸为 2880 × 1800，16:10，无透明通道。
- privacy 中提供完整中英文政策，正式 URL 已列入对应元数据。政策与官网使用同一个文本来源。
- review-notes.en.txt 是审核说明；中文说明供核对，不包含个人审核联系方式。
- assets 中提供现有品牌图标的标准尺寸导出和 AppIcon.appiconset。

公开客服邮箱：[kf953741@gmail.com](mailto:kf953741@gmail.com)。客服与隐私咨询统一通过邮件联系。

## 2026-11-06 后台进度

正式会员和团队 `63ALH54858` 已核实。Bundle ID `dev.kf.lidonce` 已注册，App Store Connect 应用记录为 `6831452648`，SKU 为 `LIDLID_MAC`。1.6.1 构建 12 已通过本机发行签名、描述文件、沙盒与隐私清单校验，经 Xcode 成功上传；上传成功不代表审核通过。

中英文名称、副标题、描述、关键词、支持和隐私网址已填写。中英文简介分别精简为 564 和 1607 字符，突出合盖出门场景，并保留免费开盖、7 天试用、一次购买、到期不打断本次及组件与网络条件。名称、副标题和全部原有关键词保留，中文新增“熄屏”，英文新增“macbook”；简介、推广语和关键词已同步后台，重新载入后逐字段核对一致，记录见 listing-upload.json。中英文商店图库已按持有人要求移除价格海报，各 5 张已同步到商店后台并重新载入核对，均显示 5/10。顺序为出门、前后对比、免费开盖、定时、隐私，图片页码也已更新为共 5 张；上传记录见 gallery-upload.json。两项内购的英文审核截图均已上传草稿；它们如实保留当前商品不可用状态，真实购买验证后还需更新。审核说明已压缩至 4000 字符以内，网页保存提示缺少审核联系人姓名和电话，此部分仍待持有人本人补齐。隐私申报由持有人确认后发布为“未收集数据”；年龄问卷计算结果为 4+（存在地区分级差异）。试用与永久解锁两项非消耗型商品已创建，价格为 US$0.00 和 US$4.99；首发地区由持有人选择为美国和中国大陆。

**先向持有人展示可安装版本、实际购买界面和对应语言的商店素材，确认后再提交审核。版本保持审核通过后手动发布。** 本机开发签名的商店模式预览副本已准备，原安装副本保留。实际 StoreKit 购买、恢复等测试及商务资料仍需完成，当前商店截图供持有人审阅确认。免费兼容组件的 Developer ID 签名已完成，公证已提交，尚待 Apple 返回可分发结果。

## 仍需开发者填写或完成

| 项目 | 状态与处理 |
| --- | --- |
| Apple Developer 会员、Team ID、App Store Connect 应用记录 | 已核实正式会员；团队 63ALH54858，应用记录 6831452648 |
| Bundle ID | dev.kf.lidonce 已注册，与构建一致 |
| 名称可用性、SKU | 中文和英文名称已保存；SKU 为 LIDLID_MAC |
| Apple 审核联系人姓名、电话、邮箱 | 提交时填写，仅供 Apple 使用；不要提交到公开 Git 仓库 |
| 免费或付费、价格、销售地区 | 应用免费下载、开盖永久免费；合盖主动领取 7 天试用、US$4.99 永久非消耗型内购；首发美国和中国大陆，当地货币由 Apple 定价 |
| 试用和永久解锁内购 | 两项商品、中英文说明和价格已创建；审核截图已上传草稿（保留真实商品不可用状态）；实际沙盒购买、更新截图与首版绑定待完成 |
| 付费协议、银行与税务信息 | 持有人已接受付费协议，银行及税务资料由持有人本人填写 |
| 年龄分级 | 已按实际功能填写问卷，Apple 计算为 4+，存在地区差异 |
| 欧盟交易者身份及地区补充资料 | 按实际销售地区、主体身份及 App Store Connect 要求填写 |
| 出口合规 | 当前未自行实现加密或提供 VPN；按最终构建核对 Apple 问卷，不自动生成豁免结论 |
| 独立组件正式分发 | Developer ID 签名已完成，公证已提交；待可分发结果和正式下载 URL，免费，不由商店主应用自动安装 |
| App Group | macOS Team-ID 组 63ALH54858.dev.kf.lidonce 无需后台注册；正式构建已验证沙盒权限，发行版 XPC 通信仍需实测 |
| 实际合盖测试 | 电池且无外接屏、屏幕唤醒回归、电源切换、开盖恢复、下一次正常睡眠均待实测 |
| 商店截图 | 中英文各 5 张 2880 × 1800 图片已上传；重新载入后对应语言均显示 5/10，已移除价格海报并更新页码。原始图保留，正式送审前由持有人确认 |
| 商店发行签名及上传校验 | 正式证书和描述文件已配置，Xcode 已成功上传 1.6.1 构建 12；Apple 处理结果与最终审核仍待核实 |

submission-inputs.example.json 只保存可分享的空模板。若记录实际审核联系人，请使用未跟踪的 submission-inputs.local.json，并在本机保管。

## 年龄分级填写参考

当前版本是本机工具，没有内置广告、聊天、用户内容发布、任意网页浏览、博彩、竞赛、医疗或健康建议、暴力、成人或恐怖内容。隐私与支持链接打开外部浏览器，不是应用内的任意网页浏览器。提及 AI 编程工具并不表示盖盖提供 AI 对话服务。

如果上架前功能改变，应按照最终功能重新回答；不要直接选择一个期望的年龄数字。

## 名称与搜索

中文名称使用“盖盖：MacBook 合盖不休眠”，英文名称使用“LidLid: Closed-Lid Keep Awake”。关键词围绕合盖、休眠、任务、计时等实际功能。Codex、Claude Code 仅在简介中作为任务场景示例出现，没有放入商店关键词，也未声称官方合作或工具控制能力。

## 截图与录屏

截图使用真实沙盒构建的中文或英文界面，周围的排版与标题用于说明功能，没有修改开关、状态或电量读数。界面操作仅展示软件状态，不充当物理合盖测试证据。

本次不提供商店 App Preview 视频。官网宣传视频含插画，继续用于官网；不要直接将其作为以真实应用录屏为主体的商店预览上传。

## 官方规格

- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [Mac screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

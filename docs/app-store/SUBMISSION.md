# 盖盖 Mac App Store 提交准备

当前代码为 1.5.1 构建 10，改为「沙盒商店主应用＋独立免费兼容组件」。正式组件 DMG 的 Developer ID 签名、公证、实机测试和商店发行签名完成前不要提交。中英文选项页面已更新为 1.5.1 实拍；其余界面截图来自 1.3.0 构建 7，需用 1.5.1 重新采集、核对。

组件架构与验证见 [COMPATIBILITY-ENGINEERING.md](../COMPATIBILITY-ENGINEERING.md)，面向用户的设置说明见 [COMPATIBILITY.zh-CN.md](../COMPATIBILITY.zh-CN.md)。所有完成状态以实际验证记录为准。

1.5.0 新增沙盒内独立的「开盖不休眠」开关，允许屏幕熄灭；此功能无需外部组件，完整合盖功能仍需组件。

## 可直接使用的资料

- metadata/zh-Hans 与 metadata/en-US 中的纯文本字段可逐项复制。
- screenshots 中按 01 至 04 的顺序上传对应语言 PNG；尺寸为 2880 × 1800，16:10，无透明通道。
- privacy 中提供完整中英文政策，正式 URL 已列入对应元数据。政策与官网使用同一个文本来源。
- review-notes.en.txt 是审核说明；中文说明供核对，不包含个人审核联系方式。
- assets 中提供现有品牌图标的标准尺寸导出和 AppIcon.appiconset。

公开客服邮箱：[kf953741@gmail.com](mailto:kf953741@gmail.com)。客服与隐私咨询统一通过邮件联系。

## 仍需开发者填写或完成

| 项目 | 状态与处理 |
| --- | --- |
| Apple Developer 会员、Team ID、App Store Connect 应用记录 | 使用自己的开发者账户核实和创建 |
| Bundle ID | 当前为 dev.kf.lidonce，注册后与构建保持一致 |
| 名称可用性、SKU | 创建应用时核实；建议内部 SKU 为 LIDLID_MAC |
| Apple 审核联系人姓名、电话、邮箱 | 提交时填写，仅供 Apple 使用；不要提交到公开 Git 仓库 |
| 免费或付费、价格、销售地区 | 尚未选定，不在宣传素材中写价格 |
| 付费协议、银行与税务信息 | 仅在收费或提供内购时需要完成相应配置 |
| 年龄分级 | 按当前功能填写问卷，由 Apple 计算，不预先宣称评级 |
| 欧盟交易者身份及地区补充资料 | 按实际销售地区、主体身份及 App Store Connect 要求填写 |
| 出口合规 | 当前未自行实现加密或提供 VPN；按最终构建核对 Apple 问卷，不自动生成豁免结论 |
| 独立组件正式分发 | Developer ID 签名、公证并提供真实下载 URL，免费，不由商店主应用自动安装 |
| App Group | 同一开发团队配置 63ALH54858.dev.kf.lidonce，验证商店发行签名下的 XPC 通信 |
| 实际合盖测试 | 电池且无外接屏、屏幕唤醒回归、电源切换、开盖恢复、下一次正常睡眠均待实测 |
| 最终截图 | 中英文选项页面为 1.5.1；其余 1.3.0 截图需重新采集核对 |
| 商店发行签名及上传校验 | 仍需配置 Apple 发行签名；本机沙盒临时签名不等于商店发行包 |

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

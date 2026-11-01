# 盖盖 Mac App Store 提交准备

商店文案、截图和隐私说明对应 1.3.0 构建 6。实际合盖测试按开发者安排延期，在完成电池供电且无外接屏的合盖运行、开盖自动结束及下一次正常睡眠检查后再提交。

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
| 实际合盖测试 | 延期，完成后补充结果 |
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

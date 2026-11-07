# 盖盖 Mac App Store 提交准备

当前候选为 1.6.1 构建 18，采用「沙盒商店主应用＋独立免费兼容组件」。开盖永久免费；合盖主动领取 7 天试用，随后 US$4.99（中国大陆 ¥38）一次购买永久解锁。试用到期仅限制新会话，不打断已开启的任务。持有人已授权真实内购验收通过后提交审核，公开发布保持手动。

## 当前验证结果

- 实际 TestFlight 17：持有人完成永久购买，应用显示已验证的「合盖永久版已解锁」。没有覆盖本地权益或伪造收据。
- 试用领取、保留原到期时间及试用恢复已通过早前真实 TestFlight 测试；永久购买取消的三条路径已通过构建 17 测试。
- 永久版恢复：之前界面显示连接失败，已重新发起，等待持有人完成 Apple 认证并核对结果。购买成功与恢复成功分别记录。
- 构建 18 将单独价格文字改为醒目的中英文购买按钮，显示 Apple 返回的当地价格，仍调用原生 ProductView 的 configuration.purchase()。本机编译、14 项现有权益／本地化测试、正式签名、描述文件、沙盒、隐私清单及安装包校验通过，匹配 dSYM 的归档已生成。尚未上传或完成新版真实运行验收。
- 免费组件 1.0.1 (2) 已正式签名、公证并发布，实际 TestFlight XPC 身份识别通过。导出应用及 DMG 内应用通过签名、公证票据、Gatekeeper 和远端 SHA256 回读。外层 DMG 没有单独公证任务。

完整状态以 [submission-status.json](submission-status.json) 为准。组件工程见 [COMPATIBILITY-ENGINEERING.md](../COMPATIBILITY-ENGINEERING.md)，用户设置说明见 [COMPATIBILITY.zh-CN.md](../COMPATIBILITY.zh-CN.md)。

## Apple 后台与素材

| 项目 | 状态 |
| --- | --- |
| 团队与应用 | 63ALH54858；dev.kf.lidonce；应用 6831452648；SKU LIDLID_MAC |
| 版本与审核草稿 | Prepare for Submission；旧构建 12 已解除关联并保存，草稿目前无项目。最终构建验收后，重新加入主版本及两项内购，再送审 |
| 价格与地区 | 应用免费、零元 7 天试用、US$4.99／¥38 永久非消耗型内购；首发美国和中国大陆；无订阅、续费或自动扣费 |
| 联系人与商务 | 审核联系人已由持有人填写并通过校验；付费协议有效、银行可用、两份税表在使用。只记录状态，不公开私密资料 |
| 隐私 | 持有人已确认并发布「未收集数据」；中英文隐私政策与官网保持同源 |
| 商店文案 | 中英文名称、简介、推广语及关键词已保存并回读核对；保留 MacBook 合盖不休眠及 Codex／Claude Code 任务场景 |
| 公开图库 | 中文、英文各五张，后台各 5/10，价格海报已移除。控制区与选项页保持捕获构建 12 的外观，来源见 captures/manifest.json |
| 私有内购图片 | 两项商品保存的 2880×1800 真实图片来自 TestFlight 14 的主购买区；构建 18 的独立购买窗口和最终审核说明仍需核对，不能把旧图标为新版 |
| TestFlight | 仅含持有人一人的 Owner validation 组；实际已安装构建 17，Apple Beta 签名及收据已核对。候选 18 仍待上传、安装和 UI 验证 |

## 提交前剩余事项

1. 完成永久版恢复购买验证，明确记录真实结果。
2. 上传并安装构建 18，核对醒目的中英文购买按钮、原生 StoreKit 动作和取消恢复；保留已验证的永久权益。
3. 整理最终真实窗口图与审核说明，选择验收通过的构建；保留两种语言各五张公开图。
4. 将主版本和两项内购加入同一审核草稿，确认三项齐全后提交。公开发布保持手动。

公开客服与隐私邮箱：[kf953741@gmail.com](mailto:kf953741@gmail.com)。不提供 GitHub 反馈入口。正式支持网址为 https://lidlid.vercel.app/zh/support/ 和 https://lidlid.vercel.app/en/support/。

metadata/zh-Hans 和 metadata/en-US 可复制商店字段；screenshots 按 01–05 上传对应语言 PNG。review-notes.en.txt 用于 Apple 审核。submission-inputs.example.json 仅为空模板；真实审核联系人保存在本机或 Apple 后台，不放入公开仓库。

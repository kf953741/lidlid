# 盖盖 App Store 隐私填写说明

对应版本为 1.3.0 构建 7。当前应用没有外部网络服务或第三方 SDK，不向开发者传输本机偏好、设备状态或诊断记录。

## App Privacy 建议填写

| 问题 | 当前构建对应答案 |
| --- | --- |
| 你或第三方合作伙伴是否从应用收集数据 | 否，不从此应用收集数据 |
| 商店隐私标签 | Data Not Collected（未收集数据） |
| 跨应用或网站追踪 | 无 |
| 广告标识符、广告或分析 SDK | 无 |
| 登录、注册与账户删除入口 | 无账号系统，不适用 |
| 隐私选择 URL | 可留空；没有服务器端账号、数据或广告选择 |

这里的“不收集”指没有将数据从设备传输给开发者或合作伙伴，并非应用不在本机处理任何信息。

## 本机数据与用途

| 数据或 API | 用途 | 去向 |
| --- | --- | --- |
| 界面语言与最长保持时间 | 保存用户偏好 | 应用沙盒 UserDefaults |
| 合盖、电量、电源、系统温度状态 | 管理会话与结束条件 | 本机处理 |
| 单调计时 | 心跳、最长保持时间、接口刷新 | 本机处理 |
| 开启、合盖、结束、恢复及错误记录 | 本机诊断 | 应用沙盒日志，无自动上传 |
| 本机记录文件的属性 | 按文件大小归档日志 | 应用沙盒内处理 |
| Clamshell 应用是否运行 | 避免相互冲突 | 本机处理，不建立应用清单 |

## PrivacyInfo xcprivacy

| 声明 | 理由 | 实际用途 |
| --- | --- | --- |
| UserDefaults | CA92.1 | 只访问本应用偏好 |
| SystemBootTime | 35F9.1 | 计算应用事件间经过的时间 |
| FileTimestamp | C617.1 | 读取本应用容器内日志文件属性 |
| NSPrivacyTracking | false | 不追踪 |
| NSPrivacyCollectedDataTypes | 空数组 | 不收集数据 |

清单随应用打包在 Contents/Resources/PrivacyInfo.xcprivacy。隐私清单、商店问卷与隐私政策分别填写，三者描述同一实际行为。

## 官网及支持渠道

隐私与支持链接在系统浏览器中打开。Vercel 托管官网和兼容组件下载。客服与隐私咨询使用公开邮箱 lidlid@bigsmart.cc。Cloudflare Email Routing 将用户主动发送的邮件转发到开发者的 Gmail，用于回应请求。政策分别说明本机数据、网站访问、下载与自愿邮件反馈。

如果未来在应用内加入反馈上传、崩溃报告、统计、支付或第三方 SDK，需要重新检查所有数据类别。可选反馈能否豁免披露应逐项对照 Apple 条件，不要直接沿用本次答案。

## 官方依据

- [App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/)
- [Required reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [App Review privacy requirements](https://developer.apple.com/app-store/review/guidelines/#privacy)

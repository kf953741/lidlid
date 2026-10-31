# 盖盖 Mac App Store 上架资料

对应 1.3.0 构建 6。打开 [index.html](index.html) 可切换语言、查看截图并复制商店字段。

| 文件 | 用途 |
| --- | --- |
| metadata/zh-Hans 和 metadata/en-US | 名称、副标题、推广语、关键词、简介、版本说明及网址，每项一个 TXT |
| screenshots | 每种语言 4 张 2880 × 1800 RGB PNG，按文件序号上传 |
| privacy | 与官网相同来源的中英文政策和随应用打包的隐私清单 |
| PRIVACY-ANSWERS.md | App Privacy 问卷填写依据 |
| review-notes.en.txt | 可复制的 Apple 审核说明 |
| SUBMISSION.md | 账户、联系方式、签名和测试等剩余事项 |
| assets | 1024 像素图标、ICNS、完整 Mac AppIcon.appiconset |
| validation.json | 元数据长度和图片规格校验 |

## 更新资料

商店文案的来源是 listing.json，政策的来源是 website/privacy-copy.mjs，截图保留原始 captures 以便核对。

修改文案后运行 node scripts/prepare-app-store.mjs。修改截图排版后先运行 swift scripts/render-app-store.swift .，再运行生成脚本。图标导出需要先通过 scripts/build.sh 构建应用。

应用内已提供按界面语言打开的隐私政策与支持链接。公开支持邮箱仍待提供；审核专用个人联系方式只在本机或 Apple 后台填写，不放入公开仓库。

import { site } from "./site.config.mjs";

// Shared by the public policy pages and the App Store material generator.
export const privacyCopy = {
  "zh": {
    "title": "盖盖隐私政策",
    "intro": "盖盖（LidLid）由 Fei Kang 开发，是一个在 Mac 本机运行的菜单栏工具。应用无需账号，不向开发者上传使用数据，也没有广告或追踪 SDK。",
    "sections": [
      [
        "免费兼容组件",
        "<p>支持商店分发的新版主应用可连接你独立安装并经 macOS 授权的免费兼容组件。组件只在本机接收盖盖的会话请求，读取睡眠、合盖、电量和温度状态，并临时管理系统睡眠设置。组件在管理员专用目录保存恢复原设置所需的版本号和一个布尔值；正常恢复后删除该记录，恢复失败时保留并重试。系统也可能保留组件运行诊断。</p><p>移除组件前，请先在组件窗口选择「恢复睡眠并移除服务」，再删除应用。请勿先删除恢复记录。组件不读取项目或 AI 对话，也不自动上传数据。</p>"
      ],
      [
        "应用在本机处理的信息",
        "<p>盖盖保存你选择的界面语言和最长保持时间，读取合盖状态、电量、电源来源、系统温度状态和运行计时，用来管理你开启的本次会话。应用也会检查可能冲突的 Clamshell 合盖控制应用是否运行。</p><p>本机诊断记录包括开启、合盖、结束、恢复状态、错误和盖盖自身的进程标识。盖盖不读取你的项目、代码、文件内容、AI 对话或浏览记录。</p>"
      ],
      [
        "数据不会自动上传",
        "<p>应用没有账号系统、广告、分析统计或开发者提供的网络服务，不会自动上传本机偏好、诊断记录或设备状态。它不使用这些信息识别你，也不进行跨应用或跨网站追踪。</p>"
      ],
      [
        "本机保存期限与删除",
        "<p>偏好会保留到你修改或清除为止。诊断记录保存在本机；记录文件达到大小限制时会归档旧文件，归档不会自动上传，也没有自动删除期限。</p><p>要清除沙盒版的全部本机偏好和记录，请先退出盖盖，再通过访达的「前往文件夹」打开并移除 <code>~/Library/Containers/dev.kf.lidonce/</code>。旧版非沙盒应用的记录可能保留在 <code>~/Library/Application Support/LidOnce/</code>，偏好可能保留在 <code>~/Library/Preferences/dev.kf.lidonce.plist</code>。仅删除应用不一定同时清除这些数据。</p>"
      ],
      [
        "打开官网或外部链接",
        "<p>在应用中点击隐私政策或支持链接，会在浏览器中打开相应页面。官网没有访客分析 SDK、营销 Cookie 或登录功能。官网由 Vercel 托管；Vercel 会为页面交付、运行和安全处理 IP 地址、浏览器及请求信息，详见 <a href=\"https://vercel.com/legal/privacy-notice\">Vercel 隐私说明</a>。这些网站访问处理与应用在本机保存的信息不同。</p>"
      ],
      [
        "下载与主动反馈",
        "<p>当前 DMG 下载由 GitHub 提供，适用 <a href=\"https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement\">GitHub 隐私声明</a>。如通过 App Store 下载或购买，相关处理由 Apple 按其适用条款完成。</p><p>如果你主动通过邮件发送联系邮箱、问题描述、机型、系统版本、日志或截图，我们会使用你提供的内容协助处理请求。邮件服务商也会按其规则处理邮件的传输与存储。请只发送处理问题所需的信息，不要包含密码、密钥或无关的私人内容。你可以通过同一邮箱请求更正或删除我们能够控制的反馈内容；第三方服务的数据处理和保留由其自身政策约束。</p>"
      ],
      [
        "联系与更新",
        `<p>有关客服或隐私的问题，请发送邮件至 <a href="mailto:${site.supportEmail}">${site.supportEmail}</a>，联系开发者 Fei Kang。也可以查看<a href="https://lidlid.vercel.app/support/">盖盖支持页面</a>的使用帮助。如果后续版本改变信息处理方式，我们会更新本政策与对应的商店隐私声明。</p>`
      ]
    ]
  },
  "en": {
    "title": "LidLid Privacy Policy",
    "intro": "LidLid is a Mac menu bar utility developed by Fei Kang. The app runs locally, requires no account, does not upload usage data to the developer, and includes no advertising or tracking SDK.",
    "sections": [
      [
        "Free compatibility component",
        "<p>The new Store-targeted app can connect to the free compatibility component you install separately and approve in macOS. It accepts local LidLid session requests, reads sleep, lid, battery and thermal state, and temporarily manages system sleep. A private administrator-owned recovery record stores only a schema version and the original boolean setting. Successful restoration removes it; failed restoration retains it for retries. macOS may also retain service diagnostics.</p><p>Before deleting the component, choose Restore sleep & remove service in its window. Do not delete recovery records first. The component does not read projects or AI conversations, or upload data automatically.</p>"
      ],
      [
        "Information handled on your Mac",
        "<p>LidLid stores your language and time-limit preferences. It reads lid state, battery level, power source, system thermal state and elapsed time to manage the session you enable. It also checks whether the potentially conflicting Clamshell lid-control app is running.</p><p>Local diagnostic records describe activation, lid events, ending, restoration, errors and identifiers of LidLid’s own processes. LidLid does not read your projects, code, file contents, AI conversations or browsing history.</p>"
      ],
      [
        "No automatic uploads",
        "<p>The app has no account system, advertising, analytics or developer-operated network service. It does not automatically upload preferences, diagnostic records or device state. It does not use this information to identify you or track you across apps or websites.</p>"
      ],
      [
        "Local retention and deletion",
        "<p>Preferences remain until you change or remove them. Diagnostic records stay on your Mac. When a record file reaches its size limit, older records are archived locally; archives are not uploaded automatically and have no automatic deletion period.</p><p>To remove all local preferences and records from the sandboxed app, quit LidLid first, then use Finder’s Go to Folder to locate and remove <code>~/Library/Containers/dev.kf.lidonce/</code>. Earlier non-sandboxed versions may have left records in <code>~/Library/Application Support/LidOnce/</code> and preferences in <code>~/Library/Preferences/dev.kf.lidonce.plist</code>. Deleting the app alone may not remove these files.</p>"
      ],
      [
        "Website and external links",
        "<p>Choosing a privacy or support link in the app opens the relevant page in your browser. This website has no visitor analytics SDK, marketing cookies or sign-in. Vercel hosts the website and processes IP addresses, browser details and requests for delivery, operation and security. See the <a href=\"https://vercel.com/legal/privacy-notice\">Vercel Privacy Notice</a>. Website request processing is separate from the information the app stores locally.</p>"
      ],
      [
        "Downloads and voluntary support requests",
        "<p>Current DMG downloads are provided through GitHub and are subject to the <a href=\"https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement\">GitHub Privacy Statement</a>. If you download or purchase through the App Store, Apple handles that transaction under its applicable terms.</p><p>If you choose to email us, we use the contact address, message, Mac model, macOS version, log or screenshot you provide to help address your request. Email service providers also process transmission and storage under their own policies. Send only information relevant to your request, without passwords, keys or unrelated private content. You can use the same email address to request correction or deletion of support content within our control. Third-party processing and retention are governed by those services’ own policies.</p>"
      ],
      [
        "Contact and updates",
        `<p>For support or privacy questions, email developer Fei Kang at <a href="mailto:${site.supportEmail}">${site.supportEmail}</a>. The <a href="https://lidlid.vercel.app/en/support/">LidLid support page</a> also provides usage help. If a future version changes how information is handled, we will update this policy and the corresponding App Store privacy disclosures.</p>`
      ]
    ]
  }
};

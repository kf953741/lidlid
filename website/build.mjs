import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { site } from './site.config.mjs';
import { privacyCopy } from './privacy-copy.mjs';

const root = path.dirname(fileURLToPath(import.meta.url));
const out = path.join(root, 'dist');
const base = site.url.replace(/\/$/, '');
const brandRevision = createHash('sha256').update(await readFile(path.join(root, 'public/assets/icon.png'))).digest('hex').slice(0, 10);
const uiSizes = JSON.parse(await readFile(path.join(root, 'ui-sizes.json'), 'utf8'));
const routes = {
  zh: { home: '/', privacy: '/privacy/', support: '/support/' },
  en: { home: '/en/', privacy: '/en/privacy/', support: '/en/support/' },
};
const e = value => String(value).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const plain = value => value.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
const arrow = '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12h14m-6-6 6 6-6 6"/></svg>';
const downloadIcon = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3v12m-5-5 5 5 5-5M5 16v4h14v-4"/></svg>';
const play = '<svg width="16" height="16" viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="m7 4 9 6-9 6V4Z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/></svg>';
const roundIcon = kind => `<svg width="29" height="29" viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.45" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${kind === 'clock' ? '<circle cx="14" cy="14" r="10"/><path d="M14 8v6l4 2"/>' : kind === 'laptop' ? '<path d="M5 19V7h18v12M2 21h24M11 21h6"/>' : '<path d="m14 3 9 4v7c0 5-9 11-9 11S5 19 5 14V7l9-4Z"/><path d="m10 14 3 3 6-6"/>'}</svg>`;
function guardian(on) {
  const outline = 'M5.2 8.2C3.2 7.8 3.2 4.9 5.4 4.4C7.3 3.8 8.5 5.4 8.5 6.8C10.4 6.1 13.4 6.2 15.7 7.3C15.3 5.5 16.7 4.2 18.3 4.8C20.3 5.4 20.5 7.9 19.1 9.1C20.6 11 22 13.3 21.7 16.6C21.4 19.3 19.3 20.8 16.5 20.8H7.3C3.9 20.8 2.1 19.1 2.3 16.1C2.5 12.8 3.4 10.1 5.2 8.2Z';
  return `<svg width="20" height="20" viewBox="0 0 24 24" aria-hidden="true">${on ? `<path fill="currentColor" fill-rule="evenodd" d="${outline}M6.2 13.3a1.9 2.4 0 1 0 3.8 0a1.9 2.4 0 1 0-3.8 0ZM14 12.6a1.9 2.4 0 1 0 3.8 0a1.9 2.4 0 1 0-3.8 0Z"/>` : `<g fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="${outline}"/><path d="M5.9 11.8C7.1 13.8 9.1 13.8 10.3 11.8M13.7 11.8C14.9 13.8 16.9 13.8 18.1 11.8"/></g>`}</svg>`;
}

const copy = {
  zh: {
    lang: 'zh-CN', brand: '盖盖', other: 'EN', otherLabel: 'Read in English',
    title: '盖盖 LidLid — MacBook 合盖不休眠，带着任务走',
    description: "Codex、Claude Code 任务还没跑完，你已经要出门？盖盖让 MacBook 合盖不休眠，本机任务继续运行。不插电、不接外接屏也能使用。开盖不休眠永久免费，合盖可免费试用 7 天。支持 M 系列 MacBook、macOS 14+。",
    nav: ['为什么用盖盖', '三步上手', '支持'], download: '下载盖盖', demo: '看 20 秒演示',
    eyebrow: 'MACBOOK 合盖不休眠', heading: '合上盖子，<br><em>带着任务走。</em>',
    lead: 'Codex、Claude Code 还在工作，你已经要走。打开盖盖，让 Mac 本机的任务在合盖后继续运行。',
    compat: "M 系列 MacBook · macOS 14+ · 开盖不休眠永久免费", artAlt: '场景插画：开发者单手携带合盖的 MacBook 出门', artLabel: '场景插画',
    uiOn: '盖盖真实中文界面，已开启本次合盖不休眠', uiOff: '盖盖真实中文界面，已关闭本次合盖不休眠',
    workIntro: '你的本机任务，继续进行', work: ['Codex', 'Claude Code', '编译', '下载'],
    storyLabel: '任务没跑完，也能先出发', storyTitle: '从「托着走」，<br>到「拿着走」。',
    storyLead: '不用双手托着开盖的电脑。去隔壁房间、换个工位，或是准备出门，都可以从容一点。',
    storyAlt: '场景对比插画：左侧双手托着开盖电脑，右侧单手拿着合盖电脑离开',
    imageNote: '移动办公场景插画。联网任务仍需可用的网络连接。',
    features: [
      ['clock', '一次开启，开盖结束', '只为本次合盖保持运行。重新开盖后自动关闭，下次需要时再开启。'],
      ['laptop', '不用接外接屏', '面向 M 系列 MacBook，电池供电也能使用，轻装换个地方。'],
      ['shield', '有分寸地保持运行', '可选最长保持时间；电池供电降至 10% 或出现严重高温时自动结束。'],
    ],
    interfaceLabel: '一个开关，就够了', interfaceTitle: '该继续时继续，<br>该休息时休息。',
    interfaceLead: '点开菜单栏图标，开启这一次。回来开盖，自动回到关闭状态。',
    checks: ["睁眼开启，闭眼关闭", "中英文界面，随时切换", "开盖永久免费，合盖免费试用 7 天"],
    interfaceLink: '看看怎么用', previewLabel: '真实界面预览，点击切换状态', on: '已开启', off: '已关闭',
    guideLabel: '两分钟上手', guideTitle: '准备出发，只要三步。', guideLead: "安装盖盖和免费兼容组件，准备好下一次出发。",
    steps: [["安装盖盖", "从 Mac App Store 安装主应用；商店入口将在上架后开放。"], ["完成首次设置", "在盖盖中点「设置免费兼容组件」，按窗口提示完成一次安装授权，再领取试用或永久解锁。"], ["开启，合盖，出发", "先启动任务，打开合盖开关，确认「已开启」。再次开盖，本次自动结束。"]],
    guideNote: '需要首次打开的帮助？', guideHelp: '查看安装与使用指南',
    faqTitle: '你可能还想知道', faqLead: '更详细的安装说明和使用帮助，都在支持页面。', faqLink: '前往支持页面',
    faq: [
      ['MacBook 合盖后，Codex、Claude 还能继续运行吗？', '盖盖面向运行在 Mac 本机的 Codex、Claude Code、编译和下载任务。开启后，本机会在这次合盖期间保持唤醒；任务仍需要它所需的网络连接和用户授权。已经在云端执行的任务，可以独立运行。'],
      ['需要插电或外接显示器吗？', '不需要外接显示器，电池供电也能使用。当前版本面向不连接外接屏的 M 系列 MacBook；电池供电降至 10% 时会结束本次。'],
      ['Mac App Store 版本可以下载了吗？', 'Mac App Store 版本正在准备上架，商店入口开放后会更新在这里。本站的 DMG 仅为免费兼容组件，需配合盖盖主应用使用。'],
    ],
    closingTitle: '任务继续，<br>你也继续出发。', closingLead: '让下一次离开工位，少一点等待。',
    storePending: 'Mac App Store 版本筹备中', storeAvailable: '在 Mac App Store 查看',
    footer: ['隐私政策', '支持与帮助'], footerLine: '为需要出发的你而做。',
    skip: '跳到主要内容', close: '关闭演示', demoTitle: '盖盖 · 20 秒使用演示',
    privacyTitle: '隐私政策', privacyMeta: '盖盖 LidLid 的隐私政策：本机偏好、诊断记录、官网托管与问题反馈。',
    privacyIntro: privacyCopy.zh.intro,
    privacySections: privacyCopy.zh.sections,
    updated: '更新日期：2026 年 11 月 22 日',
    supportTitle: '支持与使用指南', supportMeta: "盖盖 LidLid 安装与使用指南：MacBook 合盖不休眠、免费兼容组件下载、7 天试用和邮件支持。",
    supportIntro: "安装、开启、合盖出发。需要帮助，直接发邮件给我们。",
    feedback: '发送邮件', emailLabel: '邮件支持', emailHint: '欢迎发送使用问题、建议或隐私相关咨询。', installHeading: '安装与使用',
    supportSteps: [["安装盖盖", "从 Mac App Store 安装主应用；商店入口将在上架后开放。"], ["完成首次设置", "在盖盖中点「设置免费兼容组件」，按窗口提示完成一次安装授权，再领取试用或永久解锁。"], ["开启，合盖，出发", "先启动任务，打开合盖开关，确认「已开启」。再次开盖，本次自动结束。"]],
    firstLaunch: "首次安装的系统确认", firstLaunchText: "免费兼容组件已使用 Developer ID 签名并通过 Apple 公证。安装服务时，只在 macOS 系统窗口中使用 Touch ID 或管理员密码确认；盖盖不会收集你的密码。",
    supportFaq: [
      ['开着盖子也想防止休眠？', '开启独立的「开盖不休眠」开关即可，永久免费，也无需兼容组件。屏幕仍可自动熄灭；合盖或主动睡眠时暂停，开盖唤醒后恢复，退出盖盖后关闭。'],
      ['怎样切换中文和英文？', '点开盖盖右上角「选项」，在「语言」中选择简体中文、English 或跟随系统，立即生效。'],
      ['任务完成后会自动关闭吗？', '盖盖不读取 AI 对话，也不自动检测任务是否完成。开盖、手动关闭、达到所设时长或触发保护条件时，本次会话会结束。'],
      ['为什么任务还是没有继续？', '先检查是否显示「已开启」、是否连接了外接屏、是否触发低电量或高温保护。任务本身仍可能需要网络连接或用户确认；切换 Wi-Fi、VPN 时也可能断开连接。'],
      ['反馈问题时，需要提供什么？', '提供 MacBook 型号、macOS 版本、盖盖版本，以及出现问题时的操作步骤即可。请先遮住截图中的私人信息，不要上传代码、AI 对话、密钥或其他敏感内容。'],
    ],
    compatibilityTitle: "下载免费兼容组件",
    compatibilityBody: "想让 MacBook 不插电、不接外接屏也能合盖继续运行，首次使用时需要安装一次免费兼容组件。从下方下载并安装，盖盖会自动检测组件是否就绪。开盖不休眠无需安装。",
    compatibilityRemove: "需要移除时，先关闭盖盖的合盖开关，再打开兼容组件，点「恢复睡眠并移除服务」，完成后即可删除组件。需要主动睡眠时，请先关闭合盖开关。",
    supportNote: '联网任务仍需网络连接。',
    privacyLink: '阅读隐私政策', back: '返回首页', notFound: '这一页走丢了。',
    getApp: "获取盖盖",
    storeSetupTitle: "盖盖主应用",
    storeSetupBody: "Mac App Store 版本正在准备上架，正式开放后会在此提供商店链接。下方 DMG 是免费兼容组件，不能替代盖盖主应用。",
    pricing: "开盖不休眠永久免费。合盖功能可免费试用 7 天，之后 ¥38 一次购买永久解锁；没有订阅或自动续费。试用到期不会打断已经开始的会话。",
    componentDownload: "下载免费兼容组件",
    componentMeta: "v1.0.1 · M 系列 MacBook · macOS 14+ · Developer ID 签名，Apple 公证",
    componentSteps: [["放入应用程序", "打开 DMG，将 LidLid Compatibility 拖入「应用程序」。"], ["安装兼容服务", "打开组件，点「安装兼容服务」，按 macOS 提示确认，并允许其后台活动。"], ["回到盖盖", "看到「兼容组件已就绪」后，回到盖盖领取试用或永久解锁，再开启合盖开关。"]],
  },
  en: {
    lang: 'en', brand: 'LidLid', other: '中文', otherLabel: '阅读中文版',
    title: 'LidLid — Keep your MacBook awake with the lid closed',
    description: "Keep local Codex and Claude Code tasks, builds and downloads running with your MacBook lid closed, on battery without an external monitor. Open-lid mode is always free. Try closed-lid mode free for 7 days. For Apple Silicon MacBooks, macOS 14+.",
    nav: ['Why LidLid', 'Get started', 'Support'], download: 'Download for Mac', demo: 'Watch the 20s demo',
    eyebrow: 'MACBOOK CLOSED-LID KEEP-AWAKE', heading: 'Close the lid.<br><em>Carry on.</em>',
    lead: 'Codex or Claude Code is still working, but you need to go. Keep local work running while you close your MacBook and take it with you.',
    compat: "Apple Silicon · macOS 14+ · Open-lid mode is always free", artAlt: 'Illustration of a developer leaving with a closed MacBook in one hand', artLabel: 'Illustrated scene',
    uiOn: 'Actual English LidLid interface with closed-lid keep-awake on', uiOff: 'Actual English LidLid interface with closed-lid keep-awake off',
    workIntro: 'For the work running on your Mac', work: ['Codex', 'Claude Code', 'Builds', 'Downloads'],
    storyLabel: 'YOUR TASK IS RUNNING. YOU NEED TO GO.', storyTitle: 'Less balancing.<br>More moving.',
    storyLead: 'Stop carrying an open laptop in both hands. Move to another room, change desks, or head out with a little more freedom.',
    storyAlt: 'Illustrated comparison: carrying an open MacBook in both hands, then a closed MacBook in one hand',
    imageNote: 'Illustrated on-the-go scenes. Online tasks still need a working connection.',
    features: [
      ['clock', 'One session. Then back to normal.', 'Turn it on for this lid close. Reopening ends the session. Switch it on again next time you need it.'],
      ['laptop', 'No external monitor needed.', 'Made for Apple Silicon MacBooks. Works on battery, so you can move with just your laptop.'],
      ['shield', 'A little more peace of mind.', 'Choose a time limit. Sessions end at 10% on battery power or on serious thermal pressure.'],
    ],
    interfaceLabel: 'JUST ONE SWITCH', interfaceTitle: 'Keep going.<br>Then let it rest.',
    interfaceLead: 'Open the LidLid icon in your menu bar and switch on. When you return and reopen the lid, LidLid goes back to Off.',
    checks: ["Eyes open for On. Eyes closed for Off.", "English and Chinese, ready when you are.", "Open-lid mode is free. Try closed-lid mode for 7 days."],
    interfaceLink: 'See how it works', previewLabel: 'Actual interface preview. Select a state to view it.', on: 'On', off: 'Off',
    guideLabel: 'TWO MINUTES TO GET STARTED', guideTitle: 'Ready to go in three steps.', guideLead: "Install LidLid and its free compatibility component. Then get ready to go.",
    steps: [["Install LidLid.", "Get the main app from the Mac App Store. The store link will be available after launch."], ["Set up once.", "Choose Set up free compatibility component in LidLid, follow its one-time setup, then claim your trial or unlock it for life."], ["Switch on. Close. Go.", "Start your task and turn on closed-lid mode. Wait for On. Reopening ends the session automatically."]],
    guideNote: 'Need help with the first launch?', guideHelp: 'Read the setup guide',
    faqTitle: 'A few good questions.', faqLead: 'More installation help and answers live on the support page.', faqLink: 'Visit support',
    faq: [
      ['Will Codex and Claude Code keep running with the lid closed?', 'LidLid is for Codex, Claude Code, builds and downloads running locally on your Mac. It keeps your Mac awake for this session. Tasks still need their required internet connection and user approvals. Jobs already running in the cloud can run independently.'],
      ['Do I need power or an external monitor?', 'No external monitor is needed, and LidLid can run on battery. The current version is for Apple Silicon MacBooks without an external display connected. A session ends at 10% on battery power.'],
      ['Is LidLid available on the Mac App Store?', 'The Mac App Store version is being prepared for launch. We will add its link here when available. The DMG on this site contains only the free compatibility component and requires the LidLid main app.'],
    ],
    closingTitle: 'Your task carries on.<br>So can you.', closingLead: 'Make your next move with a little less waiting.',
    storePending: 'Mac App Store version in preparation', storeAvailable: 'View on the Mac App Store',
    footer: ['Privacy', 'Support'], footerLine: 'Made for the moments you need to go.',
    skip: 'Skip to content', close: 'Close demo', demoTitle: 'LidLid · 20-second demo',
    privacyTitle: 'Privacy policy', privacyMeta: 'LidLid privacy: local preferences and diagnostics, website hosting and support requests.',
    privacyIntro: privacyCopy.en.intro,
    privacySections: privacyCopy.en.sections,
    updated: 'Updated November 22, 2026',
    supportTitle: 'Support & getting started', supportMeta: "LidLid setup and support: keep your MacBook awake with the lid closed, download the free compatibility component and start a 7-day trial.",
    supportIntro: "Install, switch on, and take your work with you. Need a hand? Email us.",
    feedback: 'Email support', emailLabel: 'Email support', emailHint: 'For help, feedback or privacy questions.', installHeading: 'Install and use',
    supportSteps: [["Install LidLid.", "Get the main app from the Mac App Store. The store link will be available after launch."], ["Set up once.", "Choose Set up free compatibility component in LidLid, follow its one-time setup, then claim your trial or unlock it for life."], ["Switch on. Close. Go.", "Start your task and turn on closed-lid mode. Wait for On. Reopening ends the session automatically."]],
    firstLaunch: "Your first system confirmation", firstLaunchText: "The free compatibility app is Developer ID signed and notarized by Apple. When installing its service, confirm with Touch ID or an administrator password only in the macOS system dialog. LidLid never collects your password.",
    supportFaq: [
      ['Can I keep my Mac awake with the lid open?', 'Turn on the independent open-lid switch. It is always free and needs no compatibility component. Your display can still sleep. The mode pauses on lid close or manual sleep, resumes after reopening and wake, and turns off when you quit.'],
      ['How do I change the language?', 'Open Options → Language and select English, 简体中文 or System default. The interface changes immediately.'],
      ['Does it detect when my task finishes?', 'LidLid does not read AI conversations or automatically detect task completion. Reopening, manual off, the selected time limit or a protection condition ends the session.'],
      ['Why did my task stop anyway?', 'Check that LidLid showed On, no external display was connected, and no battery or thermal condition ended the session. Tasks may still need an internet connection or your approval. Changing Wi-Fi networks or VPNs can also interrupt connections.'],
      ['What should I include in a report?', 'Share your MacBook model, macOS version, LidLid version and the steps that caused the issue. Redact personal information in screenshots. Do not upload code, AI conversations, keys or other sensitive content.'],
    ],
    compatibilityTitle: "Download the free compatibility component",
    compatibilityBody: "For closed-lid work on battery without an external monitor, install the free component once. Download and install it below. LidLid detects when the component is ready. Open-lid mode works without it.",
    compatibilityRemove: "To remove it, turn off closed-lid mode in LidLid, open the component and choose Restore sleep & remove service. You can then delete the component. Turn closed-lid mode off before choosing Sleep as well.",
    supportNote: 'Online tasks still need a connection.',
    privacyLink: 'Read the privacy policy', back: 'Back to home', notFound: 'This page took a different path.',
    getApp: "Get LidLid",
    storeSetupTitle: "The LidLid main app",
    storeSetupBody: "The Mac App Store version is being prepared for launch. Its store link will appear here when available. The DMG below is the free compatibility component and does not replace the LidLid main app.",
    pricing: "Open-lid mode is always free. Try closed-lid mode free for 7 days, then unlock it for life for US$4.99. No subscription or automatic renewal. Trial expiry never interrupts a session already in progress.",
    componentDownload: "Download the free component",
    componentMeta: "v1.0.1 · Apple Silicon MacBooks · macOS 14+ · Developer ID signed, Apple notarized",
    componentSteps: [["Move to Applications.", "Open the DMG and drag LidLid Compatibility into Applications."], ["Install its service.", "Open the component, choose Install service and follow the macOS prompts to approve its background activity."], ["Return to LidLid.", "When you see Compatibility component ready, return to LidLid, claim the trial or unlock it for life, then turn on closed-lid mode."]],
  },
};

function appAction(locale, className = 'button') {
  const t = copy[locale];
  const href = site.appStoreUrl || `${routes[locale].support}#app-store`;
  return `<a class="${className}" href="${e(href)}">${downloadIcon}${site.appStoreUrl ? t.download : t.getApp}</a>`;
}
function header(locale, page) {
  const t = copy[locale], route = routes[locale], other = locale === 'zh' ? 'en' : 'zh';
  return `<a class="skip" href="#main">${t.skip}</a><header class="site-header"><div class="wrap nav"><a class="brand" href="${route.home}" aria-label="${t.brand} ${locale === 'zh' ? '首页' : 'home'}"><img src="/assets/icon.png?v=${brandRevision}" width="37" height="37" alt="">${t.brand}${locale === 'zh' ? '<small>LidLid</small>' : ''}</a><nav class="nav-links" aria-label="${locale === 'zh' ? '主要导航' : 'Main navigation'}"><a href="${route.home}#why">${t.nav[0]}</a><a href="${route.home}#get-started">${t.nav[1]}</a><a href="${route.support}"${page === 'support' ? ' aria-current="page"' : ''}>${t.nav[2]}</a></nav><div class="nav-actions"><a class="language" href="${routes[other][page]}" lang="${copy[other].lang}" aria-label="${t.otherLabel}">${t.other}</a>${appAction(locale, 'button small')}</div></div></header>`;
}
function storeEntry(t) {
  return site.appStoreUrl ? `<a class="store-pending" href="${e(site.appStoreUrl)}">${t.storeAvailable} ${arrow}</a>` : `<p class="store-pending">${t.storePending}</p>`;
}
function footer(locale) {
  const t = copy[locale], route = routes[locale];
  return `<footer class="site-footer"><div class="wrap"><div class="footer-top"><a class="brand" href="${route.home}"><img src="/assets/icon.png?v=${brandRevision}" width="31" height="31" alt="">${t.brand}</a><nav class="footer-links" aria-label="${locale === 'zh' ? '页脚导航' : 'Footer navigation'}"><a href="${route.privacy}">${t.footer[0]}</a><a href="${route.support}">${t.footer[1]}</a></nav></div><div class="footer-bottom"><p>© 2026 ${site.developer} · ${t.brand}</p><p>${t.footerLine}</p></div></div></footer>`;
}
function faq(items) {
  return `<div class="faq-list">${items.map(([q, a]) => `<details><summary>${q}</summary><p>${a}</p></details>`).join('')}</div>`;
}
function home(locale) {
  const t = copy[locale], route = routes[locale], asset = locale;
  return `<main id="main"><section class="wrap hero"><div class="hero-copy"><div class="eyebrow">${t.eyebrow}</div><h1>${t.heading}</h1><p>${t.lead}</p><div class="hero-actions">${appAction(locale)}<button class="button secondary" type="button" data-play-demo>${play}${t.demo}</button></div><p class="compat">${t.compat}</p></div><div class="hero-visual"><div class="hero-art"><img src="/assets/hero-${asset}.jpg" width="1400" height="700" alt="${t.artAlt}" fetchpriority="high"></div><span class="art-caption">${t.artLabel}</span><div class="hero-app"><img src="/assets/interface-on-${asset}.jpg" width="${uiSizes[locale].on[0]}" height="${uiSizes[locale].on[1]}" alt="${t.uiOn}"></div></div></section><div class="wrap work-types"><span>${t.workIntro}</span><ul>${t.work.map(word => `<li>${word}</li>`).join('')}</ul></div><section class="wrap section" id="why"><div class="section-heading"><div><span class="overline">${t.storyLabel}</span><h2>${t.storyTitle}</h2></div><p>${t.storyLead}</p></div><div class="story-picture"><img src="/assets/story-${asset}.jpg" width="1400" height="700" loading="lazy" alt="${t.storyAlt}"></div><p class="image-note">${t.imageNote}</p><div class="feature-strip">${t.features.map(([kind, title, body]) => `<div class="feature">${roundIcon(kind)}<h3>${title}</h3><p>${body}</p></div>`).join('')}</div></section><section class="section interface-section"><div class="wrap interface-grid"><div class="interface-stage"><div class="interface-image-wrap" id="interface-panel" role="tabpanel" aria-labelledby="preview-on"><img data-interface-preview data-on-width="${uiSizes[locale].on[0]}" data-on-height="${uiSizes[locale].on[1]}" data-off-width="${uiSizes[locale].off[0]}" data-off-height="${uiSizes[locale].off[1]}" src="/assets/interface-on-${asset}.jpg" data-on="/assets/interface-on-${asset}.jpg" data-off="/assets/interface-off-${asset}.jpg" width="${uiSizes[locale].on[0]}" height="${uiSizes[locale].on[1]}" loading="lazy" alt="${t.uiOn}"></div><div class="state-tabs" role="tablist" aria-label="${t.previewLabel}"><button id="preview-on" role="tab" type="button" aria-selected="true" aria-controls="interface-panel" data-preview-state="on" data-image-alt="${t.uiOn}">${guardian(true)}${t.on}</button><button id="preview-off" role="tab" type="button" aria-selected="false" aria-controls="interface-panel" tabindex="-1" data-preview-state="off" data-image-alt="${t.uiOff}">${guardian(false)}${t.off}</button></div><p class="preview-caption">${t.previewLabel}</p></div><div class="interface-copy"><span class="overline">${t.interfaceLabel}</span><h2>${t.interfaceTitle}</h2><p>${t.interfaceLead}</p><ul class="check-list">${t.checks.map(item => `<li>${item}</li>`).join('')}</ul><a class="text-link" href="#get-started">${t.interfaceLink}${arrow}</a></div></div></section><section class="wrap section" id="get-started"><div class="section-heading"><div><span class="overline">${t.guideLabel}</span><h2>${t.guideTitle}</h2></div><p>${t.guideLead}</p></div><ol class="steps" style="list-style:none;padding-left:0">${t.steps.map(([title, body], index) => `<li><span class="step-number">0${index + 1}</span><h3>${title}</h3><p>${body}</p></li>`).join('')}</ol><p class="guide-note">${t.guideNote} <a class="text-link" href="${route.support}#install">${t.guideHelp} ${arrow}</a></p></section><section class="wrap section faq-layout"><div class="faq-heading"><span class="overline">FAQ</span><h2>${t.faqTitle}</h2><p>${t.faqLead}</p><a class="text-link" href="${route.support}">${t.faqLink}${arrow}</a></div>${faq(t.faq)}</section><section class="wrap closing" id="app-store"><div><h2>${t.closingTitle}</h2><p>${t.closingLead}</p></div><div class="closing-actions">${appAction(locale, 'button light')}${storeEntry(t)}</div></section></main><dialog id="demo-dialog" aria-labelledby="demo-heading"><div class="dialog-head"><h2 id="demo-heading">${t.demoTitle}</h2><button type="button" class="dialog-close" data-close-dialog aria-label="${t.close}">×</button></div><video class="demo-video" controls playsinline preload="none" poster="/assets/hero-${asset}.jpg"><source src="/assets/demo-${asset}.mp4" type="video/mp4"></video></dialog>`;
}
function privacy(locale) {
  const t = copy[locale];
  return `<main id="main" class="wrap"><article class="document"><span class="overline">${t.brand} · PRIVACY</span><h1>${t.privacyTitle}</h1><p class="updated">${t.updated}</p><p class="intro">${t.privacyIntro}</p>${t.privacySections.map(([title, body]) => `<section><h2>${title}</h2>${body}</section>`).join('')}</article></main>`;
}
function support(locale) {
  const t = copy[locale], route = routes[locale];
  return `<main id="main" class="wrap"><article class="document"><span class="overline">${t.brand} · SUPPORT</span><h1>${t.supportTitle}</h1><p class="intro">${t.supportIntro}</p><div class="support-actions">${appAction(locale)}<a class="button secondary" href="mailto:${e(site.supportEmail)}">${t.feedback} ${arrow}</a></div><div class="support-contact"><p><strong>${t.emailLabel}</strong> <a href="mailto:${e(site.supportEmail)}">${e(site.supportEmail)}</a></p><p>${t.emailHint}</p></div><section id="app-store"><h2>${t.storeSetupTitle}</h2><p>${t.storeSetupBody}</p><p>${t.pricing}</p></section><h2 id="install">${t.installHeading}</h2><ol class="support-steps">${t.supportSteps.map(([title, body]) => `<li><strong>${title}</strong>${body}</li>`).join('')}</ol><div class="support-media"><img src="/assets/interface-on-${locale}.jpg" width="${uiSizes[locale].on[0]}" height="${uiSizes[locale].on[1]}" alt="${t.uiOn}"></div><section id="compatibility"><h2>${t.compatibilityTitle}</h2><p>${t.compatibilityBody}</p><div class="support-actions"><a class="button" href="${e(site.compatibilityDownload)}">${downloadIcon}${t.componentDownload}</a></div><p class="updated">${t.componentMeta}</p><ol class="support-steps">${t.componentSteps.map(([title, body]) => `<li><strong>${title}</strong>${body}</li>`).join('')}</ol><p>${t.compatibilityRemove}</p></section><section><h2>${t.firstLaunch}</h2><p>${t.firstLaunchText}</p></section><section><h2>${t.faqTitle}</h2>${faq(t.supportFaq)}</section><p class="notice">${t.supportNote}</p><a class="text-link" href="${route.privacy}">${t.privacyLink}${arrow}</a></article></main>`;
}
function schema(locale, page) {
  const t = copy[locale], url = base + routes[locale][page];
  const graph = [{ '@type': 'WebSite', '@id': base + '/#website', name: 'LidLid', alternateName: '盖盖', url: base + '/' }, { '@type': 'WebPage', '@id': url + '#webpage', url, name: page === 'home' ? t.title : page === 'privacy' ? t.privacyTitle : t.supportTitle, inLanguage: t.lang, isPartOf: { '@id': base + '/#website' } }];
  if (page === 'home') graph.push({ '@type': 'SoftwareApplication', name: 'LidLid', alternateName: '盖盖', applicationCategory: 'UtilitiesApplication', operatingSystem: 'macOS 14 or later; Apple Silicon MacBook', softwareVersion: site.version, url, description: t.description, image: `${base}/assets/hero-${locale}.jpg`, screenshot: `${base}/assets/interface-on-${locale}.jpg`, ...(site.appStoreUrl ? { downloadUrl: site.appStoreUrl } : {}), author: { '@type': 'Person', name: site.developer }, ...(site.appStoreUrl ? { offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD', url: site.appStoreUrl } } : {}) }, { '@type': 'FAQPage', mainEntity: t.faq.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: plain(a) } })) });
  return JSON.stringify({ '@context': 'https://schema.org', '@graph': graph }).replace(/</g, '\\u003c');
}
function layout(locale, page, body) {
  const t = copy[locale], canonical = base + routes[locale][page];
  const title = page === 'home' ? t.title : `${page === 'privacy' ? t.privacyTitle : t.supportTitle} — ${locale === 'zh' ? '盖盖 · LidLid' : 'LidLid'}`;
  const description = page === 'home' ? t.description : page === 'privacy' ? t.privacyMeta : t.supportMeta;
  return `<!doctype html><html lang="${t.lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${e(title)}</title><meta name="description" content="${e(description)}"><meta name="theme-color" content="#fbfaf6"><link rel="canonical" href="${canonical}"><link rel="alternate" hreflang="zh-CN" href="${base + routes.zh[page]}"><link rel="alternate" hreflang="en" href="${base + routes.en[page]}"><link rel="alternate" hreflang="x-default" href="${base + routes.zh[page]}"><meta property="og:type" content="website"><meta property="og:title" content="${e(title)}"><meta property="og:description" content="${e(description)}"><meta property="og:url" content="${canonical}"><meta property="og:site_name" content="LidLid · 盖盖"><meta property="og:locale" content="${locale === 'zh' ? 'zh_CN' : 'en_US'}"><meta property="og:image" content="${base}/assets/hero-${locale}.jpg"><meta property="og:image:width" content="1400"><meta property="og:image:height" content="700"><meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="${e(title)}"><meta name="twitter:description" content="${e(description)}"><meta name="twitter:image" content="${base}/assets/hero-${locale}.jpg"><link rel="icon" type="image/png" href="/assets/favicon.png?v=${brandRevision}"><link rel="apple-touch-icon" href="/assets/apple-touch-icon.png?v=${brandRevision}"><link rel="stylesheet" href="/site.css"><script type="application/ld+json">${schema(locale, page)}</script><script src="/site.js" defer></script></head><body>${header(locale, page)}${body}${footer(locale)}</body></html>`;
}

await rm(out, { recursive: true, force: true });
await mkdir(out, { recursive: true });
await cp(path.join(root, 'public'), out, { recursive: true });
const pages = [];
for (const locale of ['zh', 'en']) {
  for (const page of ['home', 'privacy', 'support']) {
    const route = routes[locale][page];
    const directory = path.join(out, route);
    await mkdir(directory, { recursive: true });
    const html = layout(locale, page, page === 'home' ? home(locale) : page === 'privacy' ? privacy(locale) : support(locale));
    await writeFile(path.join(directory, 'index.html'), html);
    pages.push({ locale, page, route });
  }
}
const notFound = layout('zh', 'home', `<main class="wrap not-found" id="main"><h1>404</h1><p>${copy.zh.notFound} / Page not found.</p><a class="button" href="/">${copy.zh.back}${arrow}</a></main>`)
  .replace(/<title>.*?<\/title>/, '<title>404 · 盖盖 LidLid</title>')
  .replace(/<script type="application\/ld\+json">.*?<\/script>/, '')
  .replace('<meta name="theme-color"', '<meta name="robots" content="noindex"><meta name="theme-color"');
await writeFile(path.join(out, '404.html'), notFound);
await writeFile(path.join(out, 'robots.txt'), `User-agent: *\nAllow: /\nSitemap: ${base}/sitemap.xml\n`);
await writeFile(path.join(out, 'sitemap.xml'), `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">${pages.map(({ page, route }) => `<url><loc>${base + route}</loc><lastmod>${site.updated}</lastmod><xhtml:link rel="alternate" hreflang="zh-CN" href="${base + routes.zh[page]}"/><xhtml:link rel="alternate" hreflang="en" href="${base + routes.en[page]}"/></url>`).join('')}</urlset>`);
console.log(`Built ${pages.length} localized pages, 404, sitemap and robots for ${base}`);

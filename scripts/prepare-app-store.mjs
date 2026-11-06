import { readFile, writeFile, mkdir, copyFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { privacyCopy } from '../website/privacy-copy.mjs';
import { site } from '../website/site.config.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.join(root, 'docs/app-store');
const listing = JSON.parse(await readFile(path.join(out, 'listing.json'), 'utf8'));
const screenshots = ['01-close-and-go', '02-carry-with-ease', '03-open-lid-free', '04-time-limits', '05-local-and-private'];
const e = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const plain = html => html.replace(/<a href="([^"]+)"[^>]*>(.*?)<\/a>/g, '$2 ($1)')
  .replace(/<\/p>/g, '\n\n').replace(/<[^>]*>/g, '').replace(/&amp;/g, '&').trim();
const info = await readFile(path.join(root, 'Info.plist'), 'utf8');
function infoValue(key) {
  const match = info.match(new RegExp(`<key>${key}</key>\\s*<string>([^<]+)</string>`));
  if (!match) throw Error(`Missing bundle information: ${key}`);
  return match[1];
}
const captures = JSON.parse(await readFile(path.join(out, 'captures/manifest.json'), 'utf8'));
const report = { version: infoValue('CFBundleShortVersionString'), build: infoValue('CFBundleVersion'), publicSupportEmail: site.supportEmail, screenshotCaptureVersion: `${captures.version} (build ${captures.build}), both languages; native main controls and options`, screenshotCaptureManifest: 'captures/manifest.json', submissionReady: false, screenshots: [], reviewScreenshots: [], metadata: {} };
if (captures.version !== report.version || captures.build !== report.build) {
  throw Error('Capture manifest differs from the current app version; recapture or verify the source captures first');
}

for (const [locale, fields] of Object.entries(listing)) {
  const limits = { name: 30, subtitle: 30, promotional_text: 170, description: 4000, release_notes: 4000 };
  report.metadata[locale] = {};
  for (const [key, limit] of Object.entries(limits)) {
    const count = [...fields[key]].length;
    if (count > limit) throw Error(`${locale} ${key}: ${count} > ${limit}`);
    report.metadata[locale][key] = count;
  }
  const keywordBytes = Buffer.byteLength(fields.keywords, 'utf8');
  if (keywordBytes > 100) throw Error(`${locale}: keywords exceed 100 bytes`);
  if (/codex|claude|caffeine|amphetamine/i.test(fields.keywords)) throw Error('Other app names in keywords');
  report.metadata[locale].keywordBytes = keywordBytes;
  await mkdir(path.join(out, 'metadata', locale), { recursive: true });
  for (const [key, value] of Object.entries(fields)) {
    await writeFile(path.join(out, 'metadata', locale, key + '.txt'), value + '\n');
  }
  for (const name of screenshots) {
    const image = await readFile(path.join(out, 'screenshots', locale, name + '.png'));
    const width = image.readUInt32BE(16), height = image.readUInt32BE(20), colorType = image[25];
    if (width !== 2880 || height !== 1800 || colorType !== 2) throw Error(`Invalid RGB screenshot: ${locale}/${name}`);
    report.screenshots.push({ locale, file: name + '.png', width, height, colorType: 'RGB, opaque' });
  }
  const reviewImage = await readFile(path.join(out, 'review-screenshots', locale, 'review-purchase-ui.png'));
  if (reviewImage.readUInt32BE(16) !== 2880 || reviewImage.readUInt32BE(20) !== 1800 || reviewImage[25] !== 2) {
    throw Error(`Invalid private review image: ${locale}`);
  }
  report.reviewScreenshots.push({ locale, file: `review-screenshots/${locale}/review-purchase-ui.png`, status: 'draft; actual product-unavailable state, replace after sandbox purchase validation' });
  const policy = privacyCopy[locale === 'zh-Hans' ? 'zh' : 'en'];
  const text = `${policy.title}\n\n${locale === 'zh-Hans' ? '更新日期：2026 年 11 月 2 日' : 'Updated November 2, 2026'}\n\n${policy.intro}\n\n`
    + policy.sections.map(([title, body]) => title + '\n' + plain(body)).join('\n\n') + '\n';
  await writeFile(path.join(out, 'privacy', locale + '.txt'), text);
  const html = `<!doctype html><html lang="${locale === 'zh-Hans' ? 'zh-CN' : 'en'}"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${e(policy.title)}</title><style>body{max-width:760px;margin:64px auto;padding:0 24px;font:17px/1.8 -apple-system,BlinkMacSystemFont,sans-serif;color:#173c33;background:#faf9f5}h1{font-size:36px;line-height:1.2}h2{font-size:23px;margin-top:36px}a{color:#236c55}code{font-size:13px;overflow-wrap:anywhere}p{margin:16px 0}.date{color:#62736b}</style><h1>${e(policy.title)}</h1><p class="date">2026-11-02</p><p>${e(policy.intro)}</p>${policy.sections.map(([title, body]) => `<section><h2>${e(title)}</h2>${body}</section>`).join('')}</html>`;
  await writeFile(path.join(out, 'privacy', locale + '.html'), html);
}

const iconDir = path.join(out, 'assets', 'AppIcon.appiconset');
await mkdir(iconDir, { recursive: true });
const images = [];
for (const size of [16, 32, 128, 256, 512]) for (const scale of [1, 2]) {
  const filename = `icon_${size}x${size}${scale === 2 ? '@2x' : ''}.png`;
  await copyFile(path.join(root, '.build/LidLid.iconset', filename), path.join(iconDir, filename));
  images.push({ size: `${size}x${size}`, idiom: 'mac', filename, scale: `${scale}x` });
}
await writeFile(path.join(iconDir, 'Contents.json'), JSON.stringify({ images, info: { version: 1, author: 'xcode' } }, null, 2) + '\n');
await copyFile(path.join(root, 'Resources/AppIcon.png'), path.join(out, 'assets/AppIcon-1024.png'));
await copyFile(path.join(root, 'dist/LidLid.app/Contents/Resources/LidLid.icns'), path.join(out, 'assets/LidLid.icns'));
await copyFile(path.join(root, 'Resources/PrivacyInfo.xcprivacy'), path.join(out, 'privacy/PrivacyInfo.xcprivacy'));
await writeFile(path.join(out, 'validation.json'), JSON.stringify(report, null, 2) + '\n');

const labels = { name: '名称 / Name', subtitle: '副标题 / Subtitle', promotional_text: '推广语 / Promotional text',
  keywords: '关键词 / Keywords', description: '简介 / Description', release_notes: '版本说明 / Release notes',
  marketing_url: '官网 / Marketing URL', support_url: '支持 / Support URL', privacy_url: '隐私政策 / Privacy Policy URL' };
const panels = Object.entries(listing).map(([locale, fields]) => `<section class="locale" id="${locale}"${locale === 'en-US' ? ' hidden' : ''}>
<div class="gallery">${screenshots.map((name, i) => `<a href="screenshots/${locale}/${name}.png" target="_blank"><img src="screenshots/${locale}/${name}.png" alt="${locale} ${name}" width="2880" height="1800"><span>0${i+1} · 2880 × 1800 · PNG ↗</span></a>`).join('')}</div>
<h2>${locale === 'zh-Hans' ? '可复制的中文商店字段' : 'English product page fields'}</h2>
${Object.entries(fields).map(([key, value]) => `<article class="field"><div><h3>${labels[key]}</h3><button class="copy" data-copy="${locale}-${key}">复制 / Copy</button></div><pre id="${locale}-${key}">${e(value)}</pre><small>${key === 'keywords' ? Buffer.byteLength(value,'utf8') + ' / 100 bytes' : ['name','subtitle','promotional_text','description','release_notes'].includes(key) ? [...value].length + ' characters' : ''}</small></article>`).join('')}
<h2>${locale === 'zh-Hans' ? '隐私与审核资料' : 'Privacy and review materials'}</h2><div class="links"><a href="privacy/${locale}.html">${locale === 'zh-Hans' ? '完整隐私政策' : 'Full privacy policy'} ↗</a><a href="privacy/${locale}.txt">TXT ↗</a><a href="review-notes.${locale === 'zh-Hans' ? 'zh-Hans' : 'en'}.txt">${locale === 'zh-Hans' ? '审核说明' : 'App Review notes'} ↗</a></div></section>`).join('');
const html = `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>盖盖 LidLid · Mac App Store 上架资料</title><style>
:root{color-scheme:light;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#173c33;background:#f6f4ee}*{box-sizing:border-box}body{margin:0}main{max-width:1160px;margin:auto;padding:56px 28px 90px}header{display:flex;gap:18px;align-items:center}header img{width:72px;height:72px}h1{font-size:34px;letter-spacing:-1px;margin:4px 0 10px}p{line-height:1.7;color:#617167}h2{margin:48px 0 20px;font-size:25px}h3{font-size:15px;margin:0}.eyebrow{font-size:12px;letter-spacing:1px;color:#597164}.tabs{display:flex;gap:8px;margin:30px 0 22px}button{font:inherit;cursor:pointer;border:1px solid #d8ddd5;border-radius:9px;padding:10px 20px;color:inherit;background:#fff}button[aria-selected=true]{background:#204f40;color:white;border-color:#204f40}button:focus-visible,a:focus-visible{outline:3px solid #d99d51;outline-offset:4px}.gallery{display:grid;grid-template-columns:1fr 1fr;gap:20px}.gallery a{display:block;text-decoration:none;border:1px solid #e2e1d8;background:#fff;border-radius:14px;overflow:hidden}.gallery img{width:100%;height:auto;display:block}.gallery span{display:block;padding:12px 16px;font-size:13px;color:#617167}.field{border:1px solid #dddfd6;border-radius:13px;background:#fff;padding:20px;margin:14px 0}.field>div{display:flex;align-items:center;justify-content:space-between;gap:16px}.field pre{font:15px/1.8 -apple-system,BlinkMacSystemFont,sans-serif;white-space:pre-wrap;overflow-wrap:anywhere;color:#324c40;margin:14px 0}.field small{color:#69776e}.copy{padding:6px 12px;font-size:12px;flex-shrink:0}.links{display:flex;gap:20px;flex-wrap:wrap}a{color:#246848}.note{margin-top:40px;padding:22px;border:1px solid #ddd8c9;border-radius:12px;background:#efede4}.note p{margin:8px 0}footer{font-size:13px;color:#657369;margin-top:40px}#status{font-size:13px;min-height:24px;color:#246848}[hidden]{display:none!important}@media(max-width:650px){main{padding:30px 18px}h1{font-size:26px}.gallery{grid-template-columns:1fr}header img{width:56px;height:56px}.field{padding:16px}}
</style></head><body><main><header><img src="assets/AppIcon-1024.png" alt="盖盖图标"><div><div class="eyebrow">LIDLID · MAC APP STORE</div><h1>盖盖上架资料</h1><p>${e(report.version)} · 构建 ${e(report.build)} · 中英文文案与真实界面截图</p></div></header><nav class="tabs" role="tablist" aria-label="资料语言"><button role="tab" aria-selected="true" aria-controls="zh-Hans" data-locale="zh-Hans">简体中文</button><button role="tab" aria-selected="false" aria-controls="en-US" data-locale="en-US">English</button></nav><div id="status" aria-live="polite"></div>${panels}<aside class="note"><h3>提交前补齐</h3><p>公开客服邮箱：<a href="mailto:${e(site.supportEmail)}">${e(site.supportEmail)}</a>。</p><p>版本已上传，正式送审和公开发布等待持有人审阅确认。Apple 审核联系人、账户商务资料及实际购买验证仍需完成。</p><p>中英文截图均来自 ${e(captures.version)} 构建 ${e(captures.build)} 的真实界面；原始截图与取景范围见 captures/manifest.json。兼容组件公证和真实购买流程仍待完成。</p><div class="links"><a href="SUBMISSION.md">提交准备清单 ↗</a><a href="PRIVACY-ANSWERS.md">隐私问卷答案 ↗</a></div></aside><footer>上传 screenshots 内的完整 PNG。此页面与总览图用于核对资料，均不是待上传截图。</footer></main><script>
for(const b of document.querySelectorAll('[data-locale]')) b.addEventListener('click',()=>{for(const s of document.querySelectorAll('.locale'))s.hidden=s.id!==b.dataset.locale;for(const t of document.querySelectorAll('[data-locale]'))t.setAttribute('aria-selected',String(t===b));document.documentElement.lang=b.dataset.locale==='zh-Hans'?'zh-CN':'en';});
for(const b of document.querySelectorAll('[data-copy]')) b.addEventListener('click',async()=>{const value=document.getElementById(b.dataset.copy).textContent;try{await navigator.clipboard.writeText(value);document.getElementById('status').textContent='已复制 / Copied';}catch{const range=document.createRange();range.selectNodeContents(document.getElementById(b.dataset.copy));const selection=getSelection();selection.removeAllRanges();selection.addRange(range);document.getElementById('status').textContent='已选中文字，请复制 / Text selected. Copy to continue.';}});
</script></body></html>`;
await writeFile(path.join(out, 'index.html'), html);
await writeFile(path.join(out, 'README.md'), `# 盖盖 Mac App Store 上架资料\n\n对应 ${report.version} 构建 ${report.build}。打开 [index.html](index.html) 可切换语言、查看截图并复制商店字段。\n\n| 文件 | 用途 |\n| --- | --- |\n| metadata/zh-Hans 和 metadata/en-US | 名称、副标题、推广语、关键词、简介、版本说明及网址，每项一个 TXT |\n| screenshots | 每种语言 5 张 2880 × 1800 RGB PNG，按文件序号上传 |\n| review-screenshots | 完整真实购买界面，仅供内购审核；商品不可用状态如实保留，购买验证后更新 |\n| privacy | 与官网相同来源的中英文政策和随应用打包的隐私清单 |\n| PRIVACY-ANSWERS.md | App Privacy 问卷填写依据 |\n| review-notes.en.txt | 可复制的 Apple 审核说明 |\n| SUBMISSION.md | 账户、联系方式、签名和测试等剩余事项 |\n| assets | 1024 像素图标、ICNS、完整 Mac AppIcon.appiconset |\n| validation.json | 元数据长度和图片规格校验 |\n\n## 更新资料\n\n商店文案的来源是 listing.json，政策的来源是 website/privacy-copy.mjs，截图保留原始 captures 以便核对。\n\n修改文案后运行 node scripts/prepare-app-store.mjs。修改截图排版后先运行 swift scripts/render-app-store.swift .，再运行生成脚本。图标导出需要先通过 scripts/build.sh 构建应用。\n\n应用内已提供按界面语言打开的隐私政策与支持链接。公开客服邮箱为 ${site.supportEmail}；审核专用个人联系方式只在本机或 Apple 后台填写，不放入公开仓库。\n`);
console.log(JSON.stringify({ locales: Object.keys(listing), screenshots: report.screenshots.length, metadata: report.metadata }, null, 2));

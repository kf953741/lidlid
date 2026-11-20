# LidLid product website

Static Chinese and English pages for the app. Built with Node.js and native HTML/CSS/JavaScript, with no third-party runtime or build packages.

## Local preview

Requires Node.js 24 or later. From this directory:

```sh
npm run build
npm run dev
```

The preview runs at `http://127.0.0.1:4173`. Production output is generated in `dist/`.

## Publish to the existing Vercel project

Use the authenticated Vercel CLI from this directory:

```sh
vercel link --yes --project lidlid --scope bigsmart
vercel --prod --yes --scope bigsmart
```

The project builds this directory with Node.js 24 and serves `dist/`. Production is `https://lidlid.vercel.app`. Local Vercel linkage and generated output are ignored by Git; do not commit credentials or environment files.

## Product updates

- `site.config.mjs` contains the production URL, DMG version/download, public support email and future App Store listing URL.
- `build.mjs` contains the localized page copy and generates the canonical URLs, alternate language links, structured data, sitemap and robots file.
- `privacy-copy.mjs` is the shared source for the public privacy pages and the Mac App Store policy exports in `docs/app-store/`.
- `public/` holds the shared CSS/JavaScript and optimized copies of the existing project artwork and actual app screenshots. Walking scenes are illustrations; videos combine those illustrations with native captures.
- The approved icon master is `Resources/AppIcon.png` at the repository root. `scripts/export-brand-assets.swift` exports the website icons and native macOS iconset; `scripts/export-ui-captures.swift` exports the localized captures and `ui-sizes.json` so preview dimensions match the real images. The build fingerprints icon URLs to refresh cached branding.
- Add `appStoreUrl` only after the listing is available. Update download copy, version, pricing metadata and privacy text to match the released app when distribution changes.

Public pages:

| Page | Chinese | English |
| --- | --- | --- |
| Product | `/` | `/en/` |
| Support | `/support/` | `/en/support/` |
| Privacy | `/privacy/` | `/en/privacy/` |

The website has no sign-in, forms, analytics SDK or marketing cookies. The privacy pages distinguish local app behavior from Vercel hosting and downloads, and voluntary email support.

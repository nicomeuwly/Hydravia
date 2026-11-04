# Hydravia — landing page

Static marketing site for the Hydravia app, plus the legal pages the App Store
requires. Built with [Astro](https://astro.build) in static mode: every page is
prerendered to plain HTML and **no JavaScript is shipped to the browser**.

```bash
npm install
npm run dev       # http://localhost:4321
npm run build     # → dist/
npm run preview   # serve dist/ locally
npm run check     # TypeScript + Astro diagnostics
```

## Before this goes live

Everything that still needs a real value lives in [`src/config.ts`](src/config.ts)
and renders on the page inside an orange dashed box, so nothing can ship
unnoticed. After filling them in:

```bash
npm run build && grep -r "À COMPLÉTER" dist/   # must return nothing
```

| Value | Why it is needed |
| --- | --- |
| `LEGAL_ENTITY` | Publisher named in both legal pages |
| `LEGAL_ADDRESS` | Required of an App Store publisher |
| `LEGAL_JURISDICTION` | Governing law in the terms |
| `CONTACT_EMAIL` | Apple requires a working support contact; GDPR requires a reachable address for data requests |
| `APP_STORE_URL` | Empty until first submission — see below |

Also update **`site`** in [`astro.config.mjs`](astro.config.mjs) and the
`Sitemap:` line in [`public/robots.txt`](public/robots.txt) if the domain is not
`hydravia.app`. Those two feed canonical URLs, `hreflang` and the sitemap.

### The download buttons

While `APP_STORE_URL` is empty the CTA renders as a dimmed, non-clickable
`<span>` rather than a dead link. Set the real URL and it becomes a link
everywhere automatically.

## Content

All copy lives in [`src/i18n/index.ts`](src/i18n/index.ts) — nothing is
hardcoded in a template. French is the source of truth and exports the key
type, so **an English catalogue missing a key fails `npm run check`** rather
than rendering `undefined`. This mirrors how the app's own `src/core/i18n`
works.

Routes: French at the root, English under `/en`.

```
/            /en           home
/privacy     /en/privacy   privacy policy
/terms       /en/terms     terms of use
```

Adding a language means adding a catalogue to `src/i18n` plus one thin page per
route; the page structure itself is shared in `src/components/Home.astro`.

### Legal pages

Written to describe what the app **actually** does, verified against the app
source rather than boilerplate. In particular:

- Coordinates *are* sent to Open-Meteo when location is granted, and the
  purchase receipt *is* sent to RevenueCat. "Nothing leaves your phone" would be
  false, so the privacy policy says exactly what goes where, in a table.
- The Screen Time section states that Hydravia cannot read usage statistics,
  which is a property of Apple's Family Controls sandbox.
- The terms carry Apple's required auto-renewing-subscription disclosures
  (renewal window, 24-hour cancellation rule, forfeited trial) and a health
  disclaimer, since the app suggests water quantities.

**These are not a substitute for legal review.** They are a solid, accurate
starting point — have them checked before publishing.

## Screenshots

`public/shots/*.webp` are real captures from the iOS simulator (iPhone 17,
1206×2622), not mockups. They were taken with the status bar overridden to
Apple's standard 09:41 / full battery:

```bash
xcrun simctl status_bar booted override \
  --time "09:41" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4
```

The device is seeded with a believable week of history — a 4-day streak with one
visible miss, and today partly filled — so the app looks used rather than empty.
Captures are downscaled to 414×900 and converted to WebP (~60 KB for all four).

To refresh them, recapture, then:

```bash
sips -Z 900 shot.png --out /tmp/s.png && cwebp -q 82 /tmp/s.png -o public/shots/home.webp
```

The phone bezel is CSS (`src/components/Phone.astro`), not part of the image, so
screenshots stay plain rectangles.

## Design

Colours, radii and shadows in `src/styles/global.css` are mirrored from the
app's `src/theme/index.ts`; the droplet-with-keyhole logo in
`src/components/Logo.astro` uses the same SVG path as the app icon. Change one,
change the other.

Space Grotesk is self-hosted in `public/fonts/` — the same face the app uses.
Serving it ourselves avoids a third-party request (and therefore a consent
banner for a font).

## Deploying

`npm run build` emits a fully static `dist/`, deployable to Netlify, Vercel,
Cloudflare Pages, GitHub Pages or any static host. No server, no runtime, no
environment variables.

Configure the host to serve `dist/` with `trailingSlash: never` semantics to
match `astro.config.mjs` — most detect this from the output automatically.

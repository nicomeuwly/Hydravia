// @ts-check
import { defineConfig } from 'astro/config';

// Static output: this site is content only, so every page is prerendered to
// plain HTML at build time and can be hosted on any static host.
//
// `site` feeds the sitemap and canonical/og:url tags. It must be the host
// that actually serves the pages: Vercel redirects hydravia.app to www, and a
// canonical that redirects sends search engines mixed signals.
export default defineConfig({
  site: 'https://www.hydravia.app',
  output: 'static',
  trailingSlash: 'never',
  build: {
    // One stylesheet inlined into the page rather than a blocking request:
    // the CSS here is small enough that a separate file costs more than it saves.
    inlineStylesheets: 'always',
  },
  compressHTML: true,
});

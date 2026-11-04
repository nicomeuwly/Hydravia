// @ts-check
import { defineConfig } from 'astro/config';

// Static output: this site is content only, so every page is prerendered to
// plain HTML at build time and can be hosted on any static host.
//
// `site` feeds the sitemap and canonical/og:url tags. Set it to the real
// domain before deploying — see README.
export default defineConfig({
  site: 'https://hydravia.app',
  output: 'static',
  trailingSlash: 'never',
  build: {
    // One stylesheet inlined into the page rather than a blocking request:
    // the CSS here is small enough that a separate file costs more than it saves.
    inlineStylesheets: 'always',
  },
  compressHTML: true,
});

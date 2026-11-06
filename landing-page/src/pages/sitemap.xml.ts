import type { APIRoute } from 'astro';
import { LANGS, localePath } from '../i18n';

/**
 * Sitemap generated from the route list rather than hand-maintained, so a new
 * page cannot be added and silently left out. Each entry declares its
 * alternates, which is how Google learns the two language versions are the
 * same page rather than duplicates.
 */
const PAGES = ['', '/privacy', '/terms'];

/** Every page is rebuilt on each deploy, so the build date is when it last
 * changed. (No `priority`: Google ignores it.) */
const LASTMOD = new Date().toISOString().slice(0, 10);

export const GET: APIRoute = ({ site }) => {
  const base = site ?? new URL('https://www.hydravia.app');
  const abs = (p: string) => new URL(p, base).href;

  const urls = PAGES.flatMap((path) =>
    LANGS.map((lang) => {
      const alternates = LANGS.map(
        (l) =>
          `    <xhtml:link rel="alternate" hreflang="${l}" href="${abs(localePath(l, path))}"/>`,
      ).join('\n');

      return `  <url>
    <loc>${abs(localePath(lang, path))}</loc>
    <lastmod>${LASTMOD}</lastmod>
${alternates}
  </url>`;
    }),
  ).join('\n');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml">
${urls}
</urlset>
`;

  return new Response(xml, {
    headers: { 'Content-Type': 'application/xml; charset=utf-8' },
  });
};

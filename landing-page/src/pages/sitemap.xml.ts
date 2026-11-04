import type { APIRoute } from 'astro';
import { LANGS, localePath } from '../i18n';

/**
 * Sitemap generated from the route list rather than hand-maintained, so a new
 * page cannot be added and silently left out. Each entry declares its
 * alternates, which is how Google learns the two language versions are the
 * same page rather than duplicates.
 */
const PAGES = [
  { path: '', priority: '1.0' },
  { path: '/privacy', priority: '0.5' },
  { path: '/terms', priority: '0.5' },
];

export const GET: APIRoute = ({ site }) => {
  const base = site ?? new URL('https://hydravia.app');
  const abs = (p: string) => new URL(p, base).href;

  const urls = PAGES.flatMap((page) =>
    LANGS.map((lang) => {
      const alternates = LANGS.map(
        (l) =>
          `    <xhtml:link rel="alternate" hreflang="${l}" href="${abs(localePath(l, page.path))}"/>`,
      ).join('\n');

      return `  <url>
    <loc>${abs(localePath(lang, page.path))}</loc>
${alternates}
    <priority>${page.priority}</priority>
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

/**
 * Everything that must be filled in before this site goes live.
 *
 * These values are centralised here on purpose: they appear across the home
 * page and both legal pages, and getting them wrong in one place while right
 * in another is exactly the sort of mistake that survives a proofread. Search
 * the built output for "[À COMPLÉTER]" to confirm none are left.
 */

/** Legal entity publishing the app and the site. */
export const LEGAL_ENTITY = '[À COMPLÉTER : raison sociale / nom de l’éditeur]';

/** Postal address of that entity. Required by the App Store for a publisher. */
export const LEGAL_ADDRESS = '[À COMPLÉTER : adresse postale complète]';

/** Country whose law governs the terms, and the competent courts. */
export const LEGAL_JURISDICTION = '[À COMPLÉTER : pays / juridiction compétente]';

/**
 * Contact address for support and privacy requests.
 *
 * Apple requires a working support URL or email on the App Store listing, and
 * GDPR requires a reachable contact for data-subject requests. A personal
 * inbox works, but a dedicated alias ages better.
 */
export const CONTACT_EMAIL = '[À COMPLÉTER : email de contact]';

/**
 * True once CONTACT_EMAIL is a real address.
 *
 * While it is still a placeholder, the templates render it as plain text
 * instead of a `mailto:` link — a link built from the placeholder opens an
 * empty draft addressed to nonsense, which looks worse than no link at all.
 */
export const HAS_CONTACT_EMAIL = !CONTACT_EMAIL.startsWith('[');

/**
 * App Store listing URL. Unknown until the app is first submitted, so the
 * download buttons render as disabled until this is set — better than a
 * confident-looking link that 404s.
 */
export const APP_STORE_URL = '';

/** Date shown on the legal pages. Update whenever their text changes. */
export const LEGAL_UPDATED = '2026-11-05';

/** Subscription products, mirroring App Store Connect (StoreKit 2). */
export const PRODUCTS = {
  monthly: 'com.nicomeuwly.hydravia.pro.monthly',
  yearly: 'com.nicomeuwly.hydravia.pro.yearly',
  lifetime: 'com.nicomeuwly.hydravia.pro.lifetime',
  trialDays: 7,
} as const;

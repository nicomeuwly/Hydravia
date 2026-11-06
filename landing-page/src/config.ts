/**
 * The publisher's details, shown on both legal pages in both languages.
 *
 * Centralised so they can't drift between pages. Hydravia is published by
 * a private individual (no company): Swiss unfair competition law (LCD art.
 * 3 al. 1 let. s) asks an online seller for their identity, a postal
 * address (not a PO box alone) and an email.
 */

/** Who publishes the app and the site. */
export const LEGAL_ENTITY = 'Nicolas Meuwly';

/**
 * Postal address, without the country: the pages add it in their own
 * language. Governing law and courts follow from it (Swiss law, the courts
 * of the publisher's domicile, canton of Fribourg).
 */
export const LEGAL_ADDRESS = 'Route de Fétigny 11, 1482 Cugy FR';

/**
 * Contact address for support and privacy requests.
 *
 * Apple requires a working support URL or email on the App Store listing, and
 * GDPR requires a reachable contact for data-subject requests. A personal
 * inbox works, but a dedicated alias ages better.
 */
export const CONTACT_EMAIL = 'contact@hydravia.app';

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
export const LEGAL_UPDATED = '2026-11-06';

/** Subscription products, mirroring App Store Connect (StoreKit 2). */
export const PRODUCTS = {
  monthly: 'com.nicomeuwly.hydravia.pro.monthly',
  yearly: 'com.nicomeuwly.hydravia.pro.yearly',
  lifetime: 'com.nicomeuwly.hydravia.pro.lifetime',
  trialDays: 7,
} as const;

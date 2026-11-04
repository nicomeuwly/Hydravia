#!/usr/bin/env node
// Generates Hydravia/Resources/Localizable.xcstrings from the Expo app's
// TypeScript catalogues (hydravia/src/core/i18n/*.ts), so the native app
// starts with exactly the copy that was written, reviewed and shipped there.
//
// Usage (Node ≥ 22.18, which strips TypeScript types natively):
//   node ios-app/Scripts/generate-strings.mjs
//
// What it does:
// - keys are kept as-is ("home.title"); Xcode generates a typed
//   LocalizedStringResource symbol per key (STRING_CATALOG_GENERATE_SYMBOLS),
//   the native counterpart of the TypeScript `TranslationKey` union;
// - {placeholders} become positional format specifiers, numbered in the
//   order they appear in ENGLISH (the development language) so every
//   language can reorder them freely;
// - placeholders listed in INTEGER_PLACEHOLDERS become %lld, every other one
//   %@ (they were pre-formatted strings in TypeScript: amounts, times, dates).
//
// The native app now owns its copy: keys were added directly to the catalogue
// (location.*, notifRecover.withReminders…, onboarding.*, unlock.saveFailed).
// Do NOT re-run this script — it would overwrite them. Edit the catalogue in
// Xcode instead; this file is kept as a record of how it was bootstrapped.

import { writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const i18nDir = resolve(here, '../../hydravia/src/core/i18n');
const output = resolve(here, '../Hydravia/Resources/Localizable.xcstrings');

const LANGUAGES = ['en', 'fr', 'de', 'es'];
const INTEGER_PLACEHOLDERS = new Set(['count', 'temp', 'max']);
const PLACEHOLDER = /\{(\w+)\}/g;

const catalogues = {};
for (const lang of LANGUAGES) {
  const module = await import(resolve(i18nDir, `${lang}.ts`));
  catalogues[lang] = module[lang];
}

const keys = Object.keys(catalogues.fr).sort();
const strings = {};

for (const key of keys) {
  const english = catalogues.en[key];
  const order = [...new Set([...english.matchAll(PLACEHOLDER)].map((m) => m[1]))];

  const convert = (value) => {
    if (order.length === 0) return value;
    return value.replaceAll('%', '%%').replace(PLACEHOLDER, (match, name) => {
      const index = order.indexOf(name);
      if (index === -1) throw new Error(`${key}: placeholder {${name}} missing from English`);
      const spec = INTEGER_PLACEHOLDERS.has(name) ? 'lld' : '@';
      return `%${index + 1}$${spec}`;
    });
  };

  const localizations = {};
  for (const lang of LANGUAGES) {
    const value = catalogues[lang][key];
    if (value === undefined) throw new Error(`${lang}: missing key ${key}`);
    localizations[lang] = { stringUnit: { state: 'translated', value: convert(value) } };
  }

  strings[key] = {
    ...(order.length > 0 ? { comment: `Arguments: ${order.join(', ')}` } : {}),
    extractionState: 'manual',
    localizations,
  };
}

const catalogue = { sourceLanguage: 'en', strings, version: '1.0' };
writeFileSync(output, `${JSON.stringify(catalogue, null, 2)}\n`);
console.log(`Wrote ${keys.length} keys × ${LANGUAGES.length} languages → ${output}`);

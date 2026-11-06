/**
 * Site copy, in the two languages the landing page ships.
 *
 * Same approach as the app's src/core/i18n: French is the source of truth and
 * exports the key type, so an English catalogue missing a key fails the build
 * instead of silently rendering `undefined`.
 *
 * The voice matches the app: second person, "tu" in French, playful but never
 * shouty. Product claims here must stay true to what the app actually does:
 * see the native app's Localizable.xcstrings for the in-product wording.
 *
 * House rules for this copy:
 *   - No em-dashes (—). Use a colon, a comma or a full stop instead.
 *   - No mention of Android. The app ships on iOS and nothing promises more.
 *   - Avoid gendered past participles in French ("tu es pris", not "absorbé"),
 *     since the reader's gender is unknown.
 */

export const LANGS = ['fr', 'en'] as const;
export type Lang = (typeof LANGS)[number];

export const fr = {
  'a11y.skip': 'Aller au contenu',
  'a11y.langSwitch': 'Changer de langue',

  'nav.how': 'Le rituel',
  'nav.features': 'Fonctionnalités',
  'nav.pricing': 'Tarifs',
  'nav.faq': 'Questions',
  'nav.cta': 'Télécharger',

  // ── Hero ──────────────────────────────────────────────────────────────────
  'hero.badge': 'iPhone et Apple Watch',
  'hero.title': 'Bois.\nDébloque.\nAvance.',
  'hero.body':
    "Un rituel d'hydratation, pas un compteur de plus. À l'heure du rappel, tes apps se verrouillent. Tu bois ton verre, tout se débloque.",
  'hero.cta': 'Télécharger sur l’App Store',
  'hero.ctaNote': 'Gratuit · Pro avec 7 jours d’essai',
  'hero.chip': 'apps débloquées',
  'hero.shotAlt':
    'Écran d’accueil de Hydravia : 1 320 ml bus sur un objectif de 2 300 ml, avec le niveau d’eau qui monte.',

  // ── Problem ───────────────────────────────────────────────────────────────
  'problem.title': 'Tu sais qu’il faut boire.\nCe n’est pas le problème.',
  'problem.body':
    'Les apps d’hydratation envoient une notification de plus, tu la balaies, et rien ne change. Le rappel passif ne marche pas : il demande de la volonté au pire moment, quand tu es déjà pris par autre chose.',
  'problem.kicker':
    'Hydravia ne te rappelle pas de boire. Il rend l’instant impossible à ignorer.',

  // ── How it works ──────────────────────────────────────────────────────────
  'how.eyebrow': 'LE RITUEL',
  'how.title': 'Trois temps, quelques secondes',
  'how.step1.title': 'Le verrou tombe',
  'how.step1.body':
    'À l’intervalle que tu as choisi, les apps que tu as sélectionnées se bloquent. Uniquement pendant tes heures actives, jamais la nuit.',
  'how.step2.title': 'Tu dis comment tu vas',
  'how.step2.body':
    'Une seule question. Ta réponse, la météo du jour et ce que tu as déjà bu donnent la quantité juste, pas un chiffre au hasard.',
  'how.step3.title': 'Tu bois, tu reprends la main',
  'how.step3.body':
    'Tu confirmes, et le verrou se lève jusqu’au prochain rappel. Le niveau d’eau monte derrière l’écran. Objectif atteint ? Le verrou se repose jusqu’au lendemain.',
  'how.shotAlt':
    'Écran de Hydravia demandant « Comment tu te sens, là, maintenant ? » avec une jauge de soif à faire glisser.',
  'how.doseAlt':
    'Hydravia affichant une quantité recommandée de 140 ml et le bouton « J’ai bu ».',

  // ── Features ──────────────────────────────────────────────────────────────
  'feat.eyebrow': 'CE QUI CHANGE',
  'feat.title': 'Pensé pour tenir dans la durée',

  'feat.dose.title': 'La quantité juste, calculée pour toi',
  'feat.dose.body':
    'Ton poids fixe l’objectif. Ce que tu as déjà bu, le temps qu’il reste avant le coucher, ta soif du moment et la température extérieure ajustent chaque verre.',

  'feat.lock.title': 'Un vrai verrou, pas une notification',
  'feat.lock.body':
    'Hydravia s’appuie sur Temps d’écran d’Apple pour bloquer les apps que tu choisis. C’est toi qui décides lesquelles : Instagram et TikTok, ou rien du tout.',

  'feat.streak.title': 'Ta régularité, sans culpabilité',
  'feat.streak.body':
    'Une semaine d’un coup d’œil, ta série en cours, ton record. De quoi te motiver, sans jamais te faire la morale.',

  'feat.pause.title': 'Objectif atteint, tu as la paix',
  'feat.pause.body':
    'Dès que ton objectif du jour est atteint, les rappels s’arrêtent et le verrou se repose jusqu’au lendemain. Pas un rappel de trop.',

  'feat.streakAlt':
    'Écran de régularité de Hydravia : série en cours, 12 objectifs atteints et graphique de la semaine.',

  // ── Widgets & Apple Watch ─────────────────────────────────────────────────
  'every.eyebrow': 'PARTOUT OÙ TU REGARDES',
  'every.title': 'Ton eau, d’un coup d’œil',
  'every.widgets.title': 'Des widgets qui servent vraiment',
  'every.widgets.body':
    'Ta progression sur l’écran d’accueil, gratuitement. Avec Pro, ajoute un verre depuis le widget sans ouvrir l’app, et suis ta journée sur l’écran verrouillé.',
  'every.watch.title': 'Et sur ton Apple Watch',
  'every.watch.body':
    'L’anneau du jour, l’heure du prochain rappel et des complications pour ton cadran. Avec Pro, tes trois quantités favorites se versent d’un tap, depuis ton poignet.',
  'every.widgetToday': 'Aujourd’hui',
  'every.widgetLeft': 'il reste {n} ml',
  'every.widgetDone': 'Objectif atteint',
  'every.widgetAdd': 'Ajouter',
  'every.widgetAlt': 'Widget Hydravia : 1 320 ml sur 2 300 ml, avec des boutons pour ajouter 230, 330 ou 510 ml.',
  'every.watchAlt': 'Hydravia sur Apple Watch : l’anneau du jour et les boutons pour verser un verre.',

  // ── Pricing ───────────────────────────────────────────────────────────────
  'price.eyebrow': 'TARIFS',
  'price.title': 'Gratuit pour commencer',
  'price.free.name': 'Gratuit',
  'price.free.price': '0 €',
  'price.free.per': 'pour toujours',
  'price.free.f1': 'Suivi de l’eau et historique complet',
  'price.free.f2': 'Rappels pendant tes heures actives',
  'price.free.f3': 'Le rituel sur une app',
  'price.free.f4': 'Widget de progression, Apple Watch et complications',
  'price.pro.name': 'Hydravia Pro',
  'price.pro.price': '2,99 €',
  'price.pro.per': 'par mois',
  'price.pro.alt': 'ou 19,99 € par an, ou 39,99 € une fois pour toutes',
  'price.pro.lead': 'Tout le gratuit, plus :',
  'price.pro.f1': 'Autant d’apps et de sites verrouillés que tu veux',
  'price.pro.f2': 'La dose ajustée à ta soif et à la météo',
  'price.pro.f3': 'Widgets d’ajout rapide et d’écran verrouillé',
  'price.pro.f4': 'Verser un verre depuis ton Apple Watch',
  'price.pro.trial': '7 jours d’essai sur les abonnements',
  'price.note': 'Prix en euros. L’App Store affiche le prix dans ta devise.',

  // ── Privacy strip ─────────────────────────────────────────────────────────
  'privacy.title': 'Local d’abord. Vraiment.',
  'privacy.p1': 'Aucun compte à créer',
  'privacy.p2': 'Ton historique reste sur ton iPhone et ta montre',
  'privacy.p3': 'Aucun traqueur publicitaire',
  'privacy.p4': 'Hydravia ne lit aucune de tes données Temps d’écran',
  'privacy.link': 'Lire la politique de confidentialité',

  // ── FAQ ───────────────────────────────────────────────────────────────────
  'faq.eyebrow': 'QUESTIONS',
  'faq.title': 'Ce qu’on nous demande',

  'faq.q1': 'Est-ce que ça bloque vraiment mon téléphone ?',
  'faq.a1':
    'Ça bloque les apps que tu as choisies, pas le téléphone entier. Les appels, les messages et tout ce que tu n’as pas sélectionné restent accessibles. Et uniquement pendant tes heures actives.',

  'faq.q2': 'Et si j’ai vraiment besoin de mon app maintenant ?',
  'faq.a2':
    'Le rituel prend quelques secondes : tu réponds à une question et tu confirmes. Rien ne t’oblige à boire pour de vrai, Hydravia te fait confiance. L’idée est de créer un temps d’arrêt, pas une prison.',

  'faq.q3': 'Pourquoi une autorisation Temps d’écran ?',
  'faq.a3':
    'C’est la seule façon, sur iOS, de bloquer d’autres apps. Apple encadre cet accès très strictement : Hydravia peut poser un verrou, mais ne peut lire aucune de tes statistiques d’usage. Tu peux retirer l’autorisation à tout moment dans les réglages.',

  'faq.q4': 'Comment la quantité est-elle calculée ?',
  'faq.a4':
    'L’objectif quotidien se calcule à partir de ton poids : environ 33 ml par kilo, toujours entre 1,5 et 4 litres. Chaque verre répartit ensuite ce qu’il te reste à boire sur les rappels qui précèdent ton heure de coucher, puis s’ajuste selon ta soif et la température extérieure.',

  'faq.q5': 'Combien ça coûte ?',
  'faq.a5':
    'Le suivi, les rappels, le widget de progression, l’Apple Watch et le rituel sur une app sont gratuits. Hydravia Pro débloque le reste : abonnement mensuel ou annuel avec sept jours d’essai, annulable à tout moment depuis les réglages de ton téléphone (on te prévient avant la fin de l’essai), ou achat à vie en un seul paiement.',

  'faq.q6': 'Est-ce que ça marche avec l’Apple Watch ?',
  'faq.a6':
    'Oui. L’app Apple Watch affiche l’eau du jour et le prochain rappel, avec des complications pour ton cadran, gratuitement. Avec Pro, tu ajoutes un verre depuis ta montre. L’iPhone garde l’historique : les deux échangent directement, sans passer par un serveur.',

  'faq.q7': 'Que se passe-t-il quand j’atteins mon objectif ?',
  'faq.a7':
    'Les rappels du jour s’arrêtent et le verrou se repose jusqu’au lendemain. Si tu relèves ton objectif ou supprimes un verre, ils reprennent.',

  // ── Final CTA ─────────────────────────────────────────────────────────────
  'final.title': 'Commence ce soir.',
  'final.body':
    'Gratuit pour commencer. Pro s’essaie sept jours, et s’annule en deux taps si ça ne te va pas.',

  // ── Footer ────────────────────────────────────────────────────────────────
  'footer.tagline': 'Le rituel d’hydratation qui tient.',
  'footer.legal': 'Légal',
  'footer.privacy': 'Confidentialité',
  'footer.terms': 'Conditions d’utilisation',
  'footer.support': 'Support',
  'footer.contact': 'Nous contacter',
  'footer.rights': 'Tous droits réservés.',

  'common.backHome': 'Retour à l’accueil',
  'common.updated': 'Dernière mise à jour',
} as const;

export type CopyKey = keyof typeof fr;
export type Catalogue = Record<CopyKey, string>;

export const en: Catalogue = {
  'a11y.skip': 'Skip to content',
  'a11y.langSwitch': 'Change language',

  'nav.how': 'The ritual',
  'nav.features': 'Features',
  'nav.pricing': 'Pricing',
  'nav.faq': 'FAQ',
  'nav.cta': 'Download',

  'hero.badge': 'iPhone and Apple Watch',
  'hero.title': 'Drink.\nUnlock.\nCarry on.',
  'hero.body':
    'A hydration ritual, not another counter. When the reminder lands, your apps lock. Drink your dose and everything opens back up.',
  'hero.cta': 'Download on the App Store',
  'hero.ctaNote': 'Free · Pro with a 7-day trial',
  'hero.chip': 'apps unlocked',
  'hero.shotAlt':
    'Hydravia home screen showing 1,320 ml of a 2,300 ml goal, with the water level rising.',

  'problem.title': 'You already know you should drink.\nThat was never the problem.',
  'problem.body':
    'Hydration apps send one more notification, you swipe it away, and nothing changes. Passive reminders ask for willpower at the worst possible moment: when you are already deep in something else.',
  'problem.kicker':
    'Hydravia does not remind you to drink. It makes the moment impossible to ignore.',

  'how.eyebrow': 'THE RITUAL',
  'how.title': 'Three beats, a few seconds',
  'how.step1.title': 'The lock lands',
  'how.step1.body':
    'At the interval you chose, the apps you picked refuse to open. Only during your active hours, never at night.',
  'how.step2.title': 'You say how you feel',
  'how.step2.body':
    'One question. Your answer, today’s weather and what you have already drunk add up to a precise dose, not a generic glass.',
  'how.step3.title': 'You drink, you get your phone back',
  'how.step3.body':
    'Confirm, and the lock lifts until the next reminder. The water level rises behind the screen. Goal reached? The lock rests until tomorrow.',
  'how.shotAlt':
    'Hydravia asking “How are you feeling right now?” with a thirst gauge to slide.',
  'how.doseAlt':
    'Hydravia showing a recommended dose of 140 ml and an “I drank it” button.',

  'feat.eyebrow': 'WHAT CHANGES',
  'feat.title': 'Built to last past week one',

  'feat.dose.title': 'A calculated dose, not a random glass',
  'feat.dose.body':
    'Your weight sets the daily goal. What you have already drunk, the time left before bed, how thirsty you are and the outside temperature adjust every dose.',

  'feat.lock.title': 'A real lock, not a notification',
  'feat.lock.body':
    'Hydravia uses Apple’s Screen Time to block the apps you choose. You decide which ones: Instagram and TikTok, or none at all.',

  'feat.streak.title': 'Your consistency, without the guilt',
  'feat.streak.body':
    'A week at a glance, your current streak, your record. Enough to keep you going, without ever lecturing you.',

  'feat.pause.title': 'Goal reached, you get some peace',
  'feat.pause.body':
    'As soon as today’s goal is reached, the reminders stop and the lock rests until tomorrow. Not one reminder too many.',

  'feat.streakAlt':
    'Hydravia consistency screen: current streak, 12 goals reached and the week’s chart.',

  'every.eyebrow': 'WHEREVER YOU LOOK',
  'every.title': 'Your water, at a glance',
  'every.widgets.title': 'Widgets that actually help',
  'every.widgets.body':
    'Your progress on the Home Screen, for free. With Pro, add a glass from the widget without opening the app, and follow your day on the Lock Screen.',
  'every.watch.title': 'And on your Apple Watch',
  'every.watch.body':
    'Today’s ring, the time of the next reminder and complications for your watch face. With Pro, your three favourite amounts pour in one tap, right from your wrist.',
  'every.widgetToday': 'Today',
  'every.widgetLeft': '{n} ml to go',
  'every.widgetDone': 'Goal reached',
  'every.widgetAdd': 'Add',
  'every.widgetAlt': 'Hydravia widget: 1,320 ml of 2,300 ml, with buttons to add 230, 330 or 510 ml.',
  'every.watchAlt': 'Hydravia on Apple Watch: today’s ring and the buttons to pour a glass.',

  'price.eyebrow': 'PRICING',
  'price.title': 'Free to start',
  'price.free.name': 'Free',
  'price.free.price': '€0',
  'price.free.per': 'forever',
  'price.free.f1': 'Water tracking and full history',
  'price.free.f2': 'Reminders during your active hours',
  'price.free.f3': 'The ritual on one app',
  'price.free.f4': 'Progress widget, Apple Watch and complications',
  'price.pro.name': 'Hydravia Pro',
  'price.pro.price': '€2.99',
  'price.pro.per': 'per month',
  'price.pro.alt': 'or €19.99 a year, or €39.99 once and for all',
  'price.pro.lead': 'Everything in Free, plus:',
  'price.pro.f1': 'As many apps and sites locked as you like',
  'price.pro.f2': 'A dose adjusted to your thirst and the weather',
  'price.pro.f3': 'Quick-add and Lock Screen widgets',
  'price.pro.f4': 'Pour a glass from your Apple Watch',
  'price.pro.trial': '7-day trial on subscriptions',
  'price.note': 'Prices in euros. The App Store shows the price in your currency.',

  'privacy.title': 'Local first. Actually.',
  'privacy.p1': 'No account to create',
  'privacy.p2': 'Your history stays on your iPhone and your watch',
  'privacy.p3': 'No advertising trackers',
  'privacy.p4': 'Hydravia cannot read any of your Screen Time data',
  'privacy.link': 'Read the privacy policy',

  'faq.eyebrow': 'QUESTIONS',
  'faq.title': 'What people ask',

  'faq.q1': 'Does it really lock my phone?',
  'faq.a1':
    'It locks the apps you picked, not the whole phone. Calls, messages and anything you did not select stay available. And only during your active hours.',

  'faq.q2': 'What if I genuinely need that app right now?',
  'faq.a2':
    'The ritual takes seconds: answer one question and confirm. Nothing forces you to actually drink, Hydravia takes your word for it. The point is a pause, not a prison.',

  'faq.q3': 'Why does it need Screen Time access?',
  'faq.a3':
    'On iOS it is the only way to block other apps. Apple keeps that access very tightly controlled: Hydravia can put a lock in place, but cannot read any of your usage statistics. You can revoke the permission at any time in Settings.',

  'faq.q4': 'How is the dose calculated?',
  'faq.a4':
    'The daily goal is worked out from your weight: roughly 33 ml per kilo, always between 1.5 and 4 litres. Each dose then spreads whatever you have left to drink across the reminders before bedtime, and adjusts for your thirst and the outside temperature.',

  'faq.q5': 'What does it cost?',
  'faq.a5':
    'Tracking, reminders, the progress widget, the Apple Watch app and the ritual on one app are free. Hydravia Pro unlocks the rest: a monthly or yearly subscription with a seven-day free trial, cancellable at any time from your phone’s settings (we let you know before the trial ends), or a one-time lifetime purchase.',

  'faq.q6': 'Does it work with Apple Watch?',
  'faq.a6':
    'Yes. The Apple Watch app shows today’s water and the next reminder, with complications for your watch face, for free. With Pro, you add a glass from your watch. Your iPhone keeps the history: the two talk directly, without going through a server.',

  'faq.q7': 'What happens when I reach my goal?',
  'faq.a7':
    'Today’s reminders stop and the lock rests until tomorrow. If you raise your goal or delete a glass, they come back.',

  'final.title': 'Start tonight.',
  'final.body':
    'Free to start. Pro has a seven-day trial, and cancels in two taps if it is not for you.',

  'footer.tagline': 'The hydration ritual that sticks.',
  'footer.legal': 'Legal',
  'footer.privacy': 'Privacy',
  'footer.terms': 'Terms of Use',
  'footer.support': 'Support',
  'footer.contact': 'Contact us',
  'footer.rights': 'All rights reserved.',

  'common.backHome': 'Back to home',
  'common.updated': 'Last updated',
};

const CATALOGUES: Record<Lang, Catalogue> = { fr, en };

export function t(lang: Lang, key: CopyKey): string {
  return CATALOGUES[lang][key];
}

/** Prefix a path for the given language. French is at the root. */
export function localePath(lang: Lang, path = ''): string {
  const clean = path === '/' ? '' : path;
  return lang === 'fr' ? clean || '/' : `/en${clean}`;
}

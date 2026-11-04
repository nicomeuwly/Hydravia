# Hydravia — mise en place Apple Developer & App Store Connect

Marche à suivre complète pour repartir de zéro avec l'app native.
Rédigée le 8 octobre 2026. Les écrans d'Apple évoluent souvent : si un libellé
diffère, cherche l'équivalent le plus proche.

**Identifiants retenus** (déjà utilisés dans le code, à reprendre à l'identique) :

| Élément | Valeur |
| --- | --- |
| Bundle ID de l'app | `com.nicomeuwly.hydravia` |
| App Group | `group.com.nicomeuwly.hydravia.blocker` |
| Extensions Screen Time (phase 7) | `com.nicomeuwly.hydravia.ShieldConfiguration`, `.ShieldAction`, `.DeviceActivityMonitor` |
| Groupe d'abonnements | `Hydravia Pro` |
| Abonnement mensuel | `com.nicomeuwly.hydravia.pro.monthly` — 1,99 $/mois, essai 7 jours |
| Abonnement annuel | `com.nicomeuwly.hydravia.pro.yearly` — 17,99 $/an, essai 7 jours |
| Team ID | `WLUNP8LN7D` |

> ⚠️ Un identifiant de produit ne peut **jamais** être réutilisé, même après
> suppression. Copie-colle exactement ceux ci-dessus.

---

## Étape 0 — À lancer tout de suite : l'entitlement Family Controls

C'est le délai le plus long (souvent 1 à 3 semaines en 2026, parfois plus) et il
conditionne la publication du verrou Screen Time.

1. [developer.apple.com](https://developer.apple.com/account) → connecte-toi.
2. Ouvre le formulaire **Family Controls (Distribution)** :
   <https://developer.apple.com/contact/request/family-controls-distribution>
3. Décris l'usage honnêtement et concrètement, par exemple :
   « Hydravia est une app de bien-être qui aide l'utilisateur à s'hydrater. À
   intervalles choisis par l'utilisateur, les apps **qu'il a lui-même
   sélectionnées** via FamilyActivityPicker sont protégées par un écran
   (ManagedSettings) jusqu'à ce qu'il confirme avoir bu. Usage individuel
   (autorisation `.individual`), aucune donnée Screen Time n'est collectée ni
   transmise. »
4. Garde la confirmation. Le statut se suit dans **Certificates, Identifiers &
   Profiles → Identifiers** (capability « Family Controls »).

Bon à savoir :
- En **développement**, Family Controls fonctionne sans cette approbation (sur
  ton iPhone, via Xcode). L'approbation n'est nécessaire que pour TestFlight et
  l'App Store.
- Depuis 2026, Apple accorde souvent l'entitlement **à toute l'équipe** plutôt
  qu'à un bundle ID : les extensions en profitent alors aussi. Si un profil de
  provisionnement ne contient pas l'entitlement après approbation, régénère-le.
- Sans réponse au bout de ~3 semaines : demande d'assistance technique (code-level
  support) en indiquant ton Team ID.

---

## Étape 1 — Compte développeur

1. **Adhésion active** : Account → Membership details. Vérifie que le programme
   Apple Developer est actif (99 $/an) et que tu es *Account Holder*.
2. **Accords** : App Store Connect → **Business** (anciennement « Agreements, Tax,
   and Banking »).
   - Accepte le **Paid Apps Agreement** (obligatoire pour vendre des
     abonnements — sans lui, aucun produit ne se charge, même en sandbox
     parfois).
   - **Banking** : IBAN du compte qui recevra les paiements.
   - **Tax** : formulaire fiscal US (pour un particulier résidant en Suisse :
     W-8BEN, en invoquant la convention fiscale Suisse–USA → 0 % de retenue sur
     les royalties) + éventuels formulaires locaux proposés.
   - Le statut doit passer à **Active** avant de tester les achats en sandbox
     de façon fiable.
3. **Small Business Program** : inscris-toi sur
   <https://developer.apple.com/app-store/small-business-program/> → commission
   de **15 %** au lieu de 30 % tant que tu restes sous 1 M$ de revenus annuels.
   Déclare les éventuels comptes développeurs associés.
4. **Statut de « trader » (UE, Digital Services Act)** : App Store Connect →
   Business → **Compliance** (ou lors de la première soumission). Une app
   payante est une activité commerciale → tu es *trader* : adresse, téléphone et
   e-mail seront vérifiés et **affichés publiquement** sur la fiche UE. Sans
   cela, l'app ne peut pas être distribuée dans l'UE.

---

## Étape 2 — Identifiants & capabilities (Certificates, Identifiers & Profiles)

1. **App Group** : Identifiers → `+` → *App Groups* →
   `group.com.nicomeuwly.hydravia.blocker` (description : « Hydravia blocker »).
2. **App ID principal** : Identifiers → `+` → *App IDs* → *App* →
   - Bundle ID explicite : `com.nicomeuwly.hydravia`
   - Capabilities à cocher :
     - **App Groups** → assigne le groupe ci-dessus
     - **Family Controls** (développement disponible immédiatement)
     - **In-App Purchase** (souvent activé par défaut)
     - (Push Notifications **non** nécessaire : les rappels sont des
       notifications locales.)
3. **Extensions** (peuvent attendre la phase 7, mais autant les créer
   maintenant) : trois App IDs explicites, chacun avec **App Groups** (même
   groupe) + **Family Controls** :
   - `com.nicomeuwly.hydravia.ShieldConfiguration`
   - `com.nicomeuwly.hydravia.ShieldAction`
   - `com.nicomeuwly.hydravia.DeviceActivityMonitor`
4. Si l'ancien App ID Expo existe déjà avec ce bundle ID, **réutilise-le** et
   vérifie simplement ses capabilities : un bundle ID n'est pas supprimable puis
   recréable librement.

> Xcode gère la signature automatiquement (« Automatically manage signing ») :
> pas besoin de créer certificats ni profils à la main.

---

## Étape 3 — Fiche de l'app dans App Store Connect

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps** → `+`
   → *New App*.
   - Plateforme : iOS
   - Nom : **Hydravia** (doit être unique sur le Store ; prévois une variante
     au cas où, ex. « Hydravia – Rituel d'eau »)
   - Langue principale : Français (ou Anglais si tu vises d'abord l'international)
   - Bundle ID : `com.nicomeuwly.hydravia`
   - SKU : `hydravia-ios` (interne, libre)
   - Accès utilisateur : *Full Access*
2. Si une ancienne fiche Expo existe déjà pour ce bundle ID, **réutilise-la**
   (une fiche ne peut pas être rattachée à un autre bundle ID).
3. **App Information** :
   - Catégorie principale : *Health & Fitness* (secondaire : *Lifestyle*)
   - Âge : questionnaire → aucun contenu sensible → 4+
   - **URL de politique de confidentialité** : `https://hydravia.app/privacy`
     (doit être **en ligne** avant la soumission — Apple la vérifie).
4. **App Privacy** (questionnaire « nutrition label ») :
   - Localisation : **approximative**, utilisée pour la fonctionnalité de l'app,
     non liée à l'identité, pas de pistage. (La position est arrondie à ~1 km et
     n'est envoyée qu'à Open-Meteo pour la température.)
   - Achats : géré par Apple, rien à déclarer côté données collectées si tu
     n'as aucun backend.
   - Aucune autre donnée collectée (tout l'historique reste sur l'appareil).

---

## Étape 4 — Abonnements

1. App → **Monetization → Subscriptions** → *Subscription Groups* → `+` →
   **Hydravia Pro**.
   - Localise le nom du groupe (fr, en, de, es) : c'est ce qui apparaît dans les
     réglages d'abonnement iOS.
2. Dans le groupe, crée **deux** abonnements :

   | Champ | Mensuel | Annuel |
   | --- | --- | --- |
   | Reference Name | Hydravia Pro Monthly | Hydravia Pro Yearly |
   | Product ID | `com.nicomeuwly.hydravia.pro.monthly` | `com.nicomeuwly.hydravia.pro.yearly` |
   | Durée | 1 mois | 1 an |
   | Prix | 1,99 $ (laisse Apple calculer les autres pays) | 17,99 $ |
   | Niveau (level) | 2 | 1 (le plus haut = annuel) |

3. Pour **chaque** abonnement :
   - **Localisations** (fr/en/de/es) : nom affiché + description courte
     (ex. « Rappels, verrou et dose adaptée »).
   - **Introductory Offer** → *Free* → **1 semaine** → tous les pays.
     (L'éligibilité est gérée par Apple : un utilisateur n'a droit qu'à un seul
     essai par groupe d'abonnements — l'app le vérifie déjà avec StoreKit 2.)
   - **Review Information** : capture d'écran du paywall (je te la fournirai) +
     note : « Abonnement qui active les rappels et le verrou Screen Time. »
4. Les produits restent en état *Ready to Submit* : ils partent en revue **avec
   la première version** de l'app (il faut les cocher dans la page de version).

---

## Étape 5 — Tester les achats

1. **En local (dès maintenant)** : l'app contient un fichier de configuration
   StoreKit (`Hydravia.storekit`) avec ces deux produits → achats simulés dans
   le simulateur et sur ton iPhone via Xcode, sans rien configurer chez Apple.
2. **Sandbox (après les étapes 1 et 4)** : App Store Connect → Users and Access →
   **Sandbox** → crée un testeur (adresse e-mail jamais utilisée pour un
   Apple Account). Sur l'iPhone : Réglages → App Store → Compte Sandbox. Les
   abonnements sandbox se renouvellent en accéléré (1 an ≈ 1 h).
3. **TestFlight** : nécessite l'entitlement Family Controls *Distribution* dès
   que les extensions Screen Time sont dans le build (phase 7).

---

## Étape 6 — Première soumission (plus tard)

- Captures d'écran 6,9" (iPhone 17 Pro Max) au minimum, dans chaque langue
  visée.
- Description, mots-clés, sous-titre (4 langues).
- Coche les deux abonnements dans la version.
- Export compliance : déjà déclaré dans l'app (`ITSAppUsesNonExemptEncryption = NO`).
- Notes pour la revue : expliquer le verrou (apps choisies par l'utilisateur,
  désactivable à tout moment) et fournir la marche à suivre pour tester.

---

## Ce que je fais de mon côté

- Phase 6 : paywall + StoreKit 2 avec les identifiants ci-dessus et un fichier
  `.storekit` local → testable sans attendre App Store Connect.
- Phase 7 : extensions Screen Time avec les bundle IDs et l'App Group ci-dessus.

Sources : [Family Controls — forums développeurs 2026](https://developer.apple.com/forums/thread/823934),
[Introductory offers — App Store Connect Help](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions),
[Implementing introductory offers — StoreKit](https://developer.apple.com/documentation/storekit/implementing-introductory-offers-in-your-app),
[Small Business Program](https://developer.apple.com/app-store/small-business-program/),
[DSA compliance — App Store Connect Help](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-eu-digital-services-act-compliance-information).

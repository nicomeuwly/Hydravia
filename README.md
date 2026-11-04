# Hydravia

Hydration reminders with a soft lock: during the day, the apps you choose stay
behind a Screen Time shield until you drink your dose. Drinking frees the phone
for one reminder interval, then the lock comes back on its own.

This repository holds the native iOS app and its marketing site.

| Folder | What it is |
| --- | --- |
| [`ios-app/`](ios-app) | The iOS app: Swift 6, SwiftUI, SwiftData, StoreKit 2, Screen Time (iOS 26+) |
| [`landing-page/`](landing-page) | Static site with the App Store's legal pages, built with Astro |

## iOS app

Requires Xcode 26 and an iPhone for the Screen Time lock (it can't run on the
simulator: authorization fails and the lock stays off).

```bash
open ios-app/Hydravia.xcodeproj

# Business-logic tests (fast, no simulator)
cd ios-app/Packages/HydraviaCore && swift test
```

- **App target** (`Hydravia/`): onboarding, home, unlock ritual, history,
  settings, paywall.
- **Three Screen Time extensions** (`Extensions/`), sharing code with the app
  through `Shared/` and an App Group:
  - `DeviceActivityMonitor` raises and lowers the shield on schedule;
  - `ShieldConfiguration` draws the screen a blocked app shows;
  - `ShieldAction` handles that screen's buttons.
- **`Packages/HydraviaCore`**: pure Swift rules (daily goal, dose, active
  window, streaks), covered by Swift Testing.
- **Subscriptions** (Hydravia Pro, monthly and yearly, each with a one-week
  trial) go through StoreKit 2. `StoreKit/Hydravia.storekit` lets you test
  them locally.

Architecture and conventions: [`ios-app/CLAUDE.md`](ios-app/CLAUDE.md).
App Store Connect setup: [`ios-app/docs/APP_STORE_SETUP.md`](ios-app/docs/APP_STORE_SETUP.md).

## Landing page

```bash
cd landing-page
npm install
npm run dev     # http://localhost:4321
npm run build   # → dist/
```

French at the root, English under `/en`, plus the privacy policy and the terms
of use. Values still to fill in before going live: see
[`landing-page/README.md`](landing-page/README.md).

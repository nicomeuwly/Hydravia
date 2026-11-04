# CLAUDE.md

Native SwiftUI rewrite of Hydravia (hydration reminders + soft-block unlock
ritual). The Expo app in `../hydravia/` is the behavioural reference: when in
doubt about product behaviour, read its source and `../hydravia/CLAUDE.md`.

## Commands

```bash
# Pure logic tests (fast, no simulator)
cd Packages/HydraviaCore && swift test

# App build (pick a simulator id from `xcodebuild -showdestinations`)
xcodebuild -project Hydravia.xcodeproj -scheme Hydravia \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath build/DerivedData build

# Regenerate the String Catalog from the Expo TypeScript catalogues
# (overwrites Localizable.xcstrings — stop using once copy is edited in Xcode)
node Scripts/generate-strings.mjs
```

## Architecture

- `Packages/HydraviaCore/` — pure Swift, no SwiftUI/SwiftData/UIKit/I/O. Daily
  goal, unlock dose, active window & reminder slots, streaks. Functions take
  "now" and a `Calendar` as parameters. New business rules go here, with Swift
  Testing tests. Day maths is always Gregorian (`gregorianInSameTimeZone`).
- `Hydravia/` — the app target, a synchronized folder (new files are picked up
  automatically; no pbxproj edits needed for sources/resources).
  - `App/` entry point and root routing
  - `Design/` tokens (`Palette`, `Font.brand…`, `Radius`, `Spacing`, `Motion`)
    and shared components (`.pressable`, `.primary`/`.primaryLight` buttons,
    `.glassCard`). Never hardcode colours, fonts or springs in a screen.
  - `Features/<Screen>/`, `Services/` (notifications, purchases, blocker,
    weather, motion), `Data/` (SwiftData models)
  - `Resources/` fonts (registered at launch by `FontRegistry`), assets,
    `Localizable.xcstrings`, `InfoPlist.xcstrings`
- `Shared/` — compiled into the app AND the three extensions (synchronized
  group in every target): `Blocker` (Screen Time state in the App Group,
  the named `ManagedSettingsStore`, DeviceActivity schedules, today's
  progress mirrored by `RootView` for the shield's copy) and
  `Shield.xcstrings` (shield copy). Explicitly `nonisolated`: the extensions
  don't use MainActor default isolation.
- `Extensions/` — `DeviceActivityMonitor` (raises the shield at wake and when
  an earned unlock ends, lowers it at bedtime), `ShieldConfiguration` (shield
  look and copy), `ShieldAction` (shield buttons; "Drink my dose" posts a
  `hydration-reminder-shield` notification that opens the ritual). Each
  `Info.plist` is excluded from its folder's membership. Class names must
  match `NSExtensionPrincipalClass`.
- `Entitlements/` — Family Controls + App Group for all four targets.
  Screen Time only works on a real device; on the simulator authorization
  fails and the lock stays off.

## Conventions

- Swift 6 language mode, default MainActor isolation, approachable concurrency.
  Use `@Observable` + `@Environment` injection; services behind protocols.
- Strings: use the generated symbols (`Text(.homeTitle)`), never literals.
  Keys keep the Expo names (`home.title`); placeholders are positional.
- Light-only UI for now, but every colour goes through `Palette`.
- Identifiers that must never drift: bundle `com.nicomeuwly.hydravia`, App
  Group `group.com.nicomeuwly.hydravia.blocker`, RevenueCat entitlement
  `hydravia_pro`, products `monthly` / `yearly`.

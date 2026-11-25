# Working on Hydravia (iOS)

How changes are made, checked, committed and shipped. CLAUDE.md describes the
code; this file describes the way of working. Pending work lives in
`EN_SUSPENS.md`.

## Development with ECC

Use the ECC plugin's skills and agents for the work they cover, instead of an
ad hoc approach:

| Work | ECC skill or agent |
|---|---|
| SwiftUI views, `@Observable` state, navigation | `ecc:swiftui-patterns` |
| Concurrency, MainActor isolation, `@concurrent` | `ecc:swift-concurrency-6-2` |
| Persistence behind actors (App Group, SwiftData) | `ecc:swift-actor-persistence` |
| Services behind protocols, testable seams | `ecc:swift-protocol-di-testing` |
| iOS 26 Liquid Glass UI (app, widgets) | `ecc:liquid-glass-design` |
| New business rule in HydraviaCore | `ecc:tdd-workflow` (test first, Swift Testing) |
| Build or signing failure | agent `ecc:swift-build-resolver` |
| Review after a change | agent `ecc:swift-reviewer` (plus `ecc:security-reviewer` when data leaves the device or entitlements change) |
| Strings in several catalogs | `ecc:i18n-sync` |
| Before calling work done | `ecc:verification-loop` |
| Polish of spacing, motion, hit areas | `ecc:make-interfaces-feel-better` |

Other skills:

- `diagnosing-bugs` for a bug that isn't obvious, before changing code.
- `run` to launch the app in the simulator, and the iOS Simulator tool to see a
  change working. Screen Time doesn't work on the simulator: lock changes are
  checked on a device.
- Marketing and store work: `launch-video` and the motion skills for videos,
  `marketing:*` for copy, `seo-geo-aeo:seo-geo-aeo` for the landing page.

## Checks before a commit

1. `cd Packages/HydraviaCore && swift test` when HydraviaCore changed.
2. The app builds for the simulator (command in CLAUDE.md). A change to a
   target's settings is checked in every bundle: the app, the four
   extensions, the watch app and its complications.
3. A visible change is looked at in the simulator, in French and English.
4. New strings exist in every catalog (FR, EN, DE, ES), and in the widget,
   watch and shield catalogs when they show them.

## Commits

- Commit or push only when asked. No attribution lines.
- One subject per commit, written as a sentence that says what is now true
  (see `git log`), in English.
- `ios-app/docs/` is local only (ignored): store listing, nominations,
  strategy, screenshots, videos. Never add it back to git.
- Never commit build output, `.mov` takes or secrets.

## Versions and tags

- Work happens on `main`. A long feature gets a short branch, merged as soon
  as it's done. There is no branch per version.
- Every target carries the same version: `MARKETING_VERSION` and
  `CURRENT_PROJECT_VERSION` are set in all 14 build configurations (7 targets
  × Debug and Release) together. Check the built bundles afterwards: every
  `Info.plist` must show the same `x.y.z (n)`.
- The build number goes up by one with every upload to App Store Connect,
  even for the same version.
- Bump the version in its own commit: `Version x.y.z (build n) for every
  target…`.
- Each build sent to Apple gets an annotated tag on the commit it was
  archived from, then the tag is pushed:

  ```bash
  git tag -a v1.0.1 <commit> -m "1.0.1 (build 2)"
  git push origin v1.0.1
  ```

- A bug in a released version while `main` holds unreleased work: branch from
  its tag (`git switch -c hotfix/1.0.2 v1.0.1`), fix, tag the new build,
  then bring the fix back to `main`.
- Shipped so far: `v1.0` (build 1, e2eb2bb), `v1.0.1` (build 2, 4fd1812).

## App Store Connect

- The texts to enter (subtitle, keywords, descriptions, review notes) are in
  `docs/APP_STORE_LISTING.md`, the featuring texts in
  `docs/APPLE_NOMINATIONS.md`. Change the file first, then the store.
- Subtitle, keywords and screenshots only change with a new version; the
  promotional text changes at any time.
- Nothing is submitted, sent or released (a version, a nomination, an event)
  without the owner's explicit yes in the conversation.
- An in-app event whose deep link needs new code goes to review together with
  the version that contains that code.
- Deep links use the `hydravia://` scheme (`AppRouter.open`): `streak`,
  `home`, `paywall`. A new link is added there and tested with
  `xcrun simctl openurl`.

## Simulator hygiene

Marketing captures change the simulator's state. Afterwards:

- Language back to French (Switzerland): `AppleLocale fr_CH`,
  `AppleLanguages (fr-CH)`, then reboot the simulator.
- `xcrun simctl status_bar <udid> clear`.
- Units back to Automatic in Settings, and test glasses removed from today's
  history.

# Known issues

| # | Issue | Notes |
|---|---|---|
| 1 | Device tests partly done | Background sync is verified on real hardware (2026-11-21): an edit made on the watch with the phone app closed was there when the phone app opened, name and all. The complication is not verified yet — it has never been seen on a watch face. Blocked on #2. |
| 2 | A watch app whose version never changes is not re-pushed to the watch | `CURRENT_PROJECT_VERSION` is `1` and `MARKETING_VERSION` `1.3` in every configuration, so every build of the watch app is `1.3 (1)`. iOS compares those two numbers to decide whether the copy on the watch is stale, so a watch app that gained a complication this morning looks identical to yesterday's and is never replaced. Restarting the watch does not help; the old copy is intact, it simply has no `PlugIns/`. Delete the app from the watch and let the iPhone's Watch app reinstall it, or bump the build number before installing. Enabling Developer Mode on the watch and pairing it in Xcode avoids the whole problem, because Xcode then installs the watch app directly. |
| 3 | App Group must exist in the developer account | `group.com.lmunck.NSSB` on the watch app and `NSSBComplications`. Provisioned and verified 2026-11-21: once signed in to Xcode, automatic signing created profiles carrying the group, and the device build went through. Still a setup step on a fresh account or machine. |
| 4 | Complication only hears about phone edits through the watch | Application context reaches the watch when the watch app next runs. A phone-side `transferCurrentComplicationUserInfo` could push sooner if that turns out to matter. |
| 5 | `breaks` can never shrink across devices | Merge is a union. Fine while nothing deletes breaks; a future reset needs a tombstone or a reset epoch. |
| 6 | `PresenceRepository.swift:973` warns on the CI toolchain | "no 'async' operations occur within 'await' expression". `DEVELOPMENT.md` says the project builds with no warnings of its own, so this is likely a difference between the runner's Xcode and the local one. Confirmed present on `main`'s own CI run (2026-11-21, after the infrastructure merge) — it is the only warning the project emits there. Whether it also appears locally is still unverified. |
| 7 | WatchConnectivity between simulators | Per `DEVELOPMENT.md`, `isReachable` can stay false on a paired, connected simulator pair. Application context may still get through there, but this is unverified. |
| 8 | Firestore rules have no automated tests | See `DEVELOPMENT.md` → "Rules tests (not set up)". |

## Verifying the complication is really installed

The watch face picker is a poor test, because an absent complication and an unregistered
one look the same. watchOS keeps a plug-in registry, and it answers directly:

```
xcrun simctl spawn <watch-sim-udid> pluginkit -mAv -p com.apple.widgetkit-extension
```

`com.lmunck.NSSB.watchkitapp.complications` appears there the moment the watch app is
installed. It was checked this way on 2026-11-21 against a clean watchOS 27 simulator and
registered immediately, which is what ruled the code and the bundle out and pointed at #2.

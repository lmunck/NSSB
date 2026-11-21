# Known issues

| # | Issue | Notes |
|---|---|---|
| 1 | Not tested on devices | Background sync: edit on the watch with the phone app closed, then open it. Complication: add each family, start a break, check the countdown and that the count goes up at the end. |
| 2 | App Group must exist in the developer account | `group.com.lmunck.NSSB` on the watch app and `NSSBComplications`. If a device build fails on provisioning, add it under Signing & Capabilities. |
| 3 | Complication only hears about phone edits through the watch | Application context reaches the watch when the watch app next runs. A phone-side `transferCurrentComplicationUserInfo` could push sooner if that turns out to matter. |
| 4 | `breaks` can never shrink across devices | Merge is a union. Fine while nothing deletes breaks; a future reset needs a tombstone or a reset epoch. |
| 5 | `PresenceRepository.swift:973` warns on the CI toolchain | "no 'async' operations occur within 'await' expression". `DEVELOPMENT.md` says the project builds with no warnings of its own, so this is likely a difference between the runner's Xcode and the local one. Confirmed present on `main`'s own CI run (2026-11-21, after the infrastructure merge) — it is the only warning the project emits there. Whether it also appears locally is still unverified. |
| 6 | WatchConnectivity between simulators | Per `DEVELOPMENT.md`, `isReachable` can stay false on a paired, connected simulator pair. Application context may still get through there, but this is unverified. |
| 7 | Firestore rules have no automated tests | See `DEVELOPMENT.md` → "Rules tests (not set up)". |

# Known issues

| # | Issue | Notes |
|---|---|---|
| 1 | `LiveViewTests.testTheWalkOverNeverBlinks` is intermittent on the GitHub macOS runner | On the first CI run, on unmodified `main` code, the arrival was caught part way in once instead of the required twice ("they reached your cigarette without crossing the gap"). The next run, with this branch on top, passed. The film depends on frame rate (`DEVELOPMENT.md` aims for about 4 fps), and the runner is slower. Decide whether the threshold should scale with the measured frame rate, or the film should run only locally. It shouldn't simply be skipped. |
| 2 | Not tested on devices | Background sync: edit on the watch with the phone app closed, then open it. Complication: add each family, start a break, check the countdown and that the count goes up at the end. |
| 3 | App Group must exist in the developer account | `group.com.lmunck.NSSB` on the watch app and `NSSBComplications`. If a device build fails on provisioning, add it under Signing & Capabilities. |
| 4 | Complication only hears about phone edits through the watch | Application context reaches the watch when the watch app next runs. A phone-side `transferCurrentComplicationUserInfo` could push sooner if that turns out to matter. |
| 5 | `breaks` can never shrink across devices | Merge is a union. Fine while nothing deletes breaks; a future reset needs a tombstone or a reset epoch. |
| 6 | `PresenceRepository.swift:973` warns on the CI toolchain | "no 'async' operations occur within 'await' expression". `DEVELOPMENT.md` says the project builds with no warnings of its own, so this is probably a difference between the runner's Xcode and the local one (unverified). It is already present on `main`. |
| 7 | WatchConnectivity between simulators | Per `DEVELOPMENT.md`, `isReachable` can stay false on a paired, connected simulator pair. Application context may still get through there, but this is unverified. |
| 8 | Firestore rules have no automated tests | See `DEVELOPMENT.md` → "Rules tests (not set up)". |

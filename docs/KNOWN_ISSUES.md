# Known issues

| # | Issue | Notes |
|---|---|---|
| 1 | `LiveViewTests.testTheWalkOverNeverBlinks` is intermittent on the GitHub macOS runner | Four runs on 2026-11-21 settle that it is the runner and not the code: the same test code failed, passed, then failed again on the PR branch, and then passed on `main` once the branch was merged. The failure is always the same assertion (`SynchronyTests.swift:1323`, "they reached your cigarette without crossing the gap") — the arrival is caught part way in once instead of the required twice. The film depends on frame rate (`DEVELOPMENT.md` aims for about 4 fps), and the runner is slower. Decide whether the threshold should scale with the measured frame rate, or the film should run only locally. It shouldn't simply be skipped. |
| 2 | Not tested on devices | Background sync: edit on the watch with the phone app closed, then open it. Complication: add each family, start a break, check the countdown and that the count goes up at the end. |
| 3 | App Group must exist in the developer account | `group.com.lmunck.NSSB` on the watch app and `NSSBComplications`. If a device build fails on provisioning, add it under Signing & Capabilities. |
| 4 | Complication only hears about phone edits through the watch | Application context reaches the watch when the watch app next runs. A phone-side `transferCurrentComplicationUserInfo` could push sooner if that turns out to matter. |
| 5 | `breaks` can never shrink across devices | Merge is a union. Fine while nothing deletes breaks; a future reset needs a tombstone or a reset epoch. |
| 6 | `PresenceRepository.swift:973` warns on the CI toolchain | "no 'async' operations occur within 'await' expression". `DEVELOPMENT.md` says the project builds with no warnings of its own, so this is likely a difference between the runner's Xcode and the local one. Confirmed present on `main`'s own CI run (2026-11-21, after the infrastructure merge) — it is the only warning the project emits there. Whether it also appears locally is still unverified. |
| 7 | WatchConnectivity between simulators | Per `DEVELOPMENT.md`, `isReachable` can stay false on a paired, connected simulator pair. Application context may still get through there, but this is unverified. |
| 8 | Firestore rules have no automated tests | See `DEVELOPMENT.md` → "Rules tests (not set up)". |

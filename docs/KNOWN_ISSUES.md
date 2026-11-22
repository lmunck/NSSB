# Known issues

Eight. **One needs you** (#2). Three are design limits with nothing to do about
them. Four are things nobody has checked yet.

| # | Issue | Needs |
|---|---|---|
| 1 | Complication never seen on a watch | waiting on #2 |
| 2 | Watch never gets the new watch app | **you** |
| 3 | App Group on a fresh machine | you, once |
| 4 | Phone edits reach the complication late | nothing |
| 5 | `breaks` can only grow | nothing |
| 6 | One warning on CI | nothing |
| 7 | Watch sync between simulators | a check |
| 8 | Firestore rules untested | a test suite |

---

## Needs you

### 2. The watch never gets the new watch app

**What** — every build of the watch app is `1.3 (1)`. `CURRENT_PROJECT_VERSION`
and `MARKETING_VERSION` are hardcoded in all eight build configurations.

**Why it matters** — iOS reads those two numbers to decide whether the copy on
the watch is stale. A watch app that gained a complication this morning looks
identical to yesterday's, so iOS leaves the old one alone. The old copy works
fine. It just has no `PlugIns/` inside it.

**Restarting the watch does not help.** It re-registers the same old bundle.

**Do this** — pick one:

- Long-press NSSB on the watch → delete → let the iPhone's Watch app reinstall it.
- Bump the build number, then rebuild and install.
- Best: turn on Developer Mode on the watch and pair it in Xcode. Xcode then
  installs the watch app directly and ignores version numbers.

### 3. The App Group has to exist in the developer account

**What** — `group.com.lmunck.NSSB`, on the watch app and on `NSSBComplications`.

**Status** — done and verified on this machine (2026-11-21). Signing in to Xcode
was enough; automatic signing made profiles carrying the group.

**Do this** — only on a fresh account or machine, and only if a device build
fails on provisioning: add it under Signing & Capabilities.

---

## Design limits — nothing to do

### 4. Phone edits reach the complication late

Application context reaches the watch when the watch app next runs. A phone-side
`transferCurrentComplicationUserInfo` would push sooner, if that ever matters.

### 5. `breaks` can only grow

Merging two devices is a union, so a break can never be removed. Fine while
nothing deletes breaks. A future reset feature needs a tombstone or a reset epoch.

### 6. One warning on the CI toolchain

`PresenceRepository.swift:973` — "no 'async' operations occur within 'await'
expression". It is the only warning the project emits on CI, confirmed on `main`
2026-11-21. `DEVELOPMENT.md` says the project builds clean, so this is probably a
difference between the runner's Xcode and the local one. Unverified locally.

---

## Not checked yet

### 1. The complication has never been seen on a watch face

Blocked on #2 — it has never actually been installed on the watch.

The code and the bundle are **ruled out**: four complete views, a real
`TimelineProvider`, correct target membership, `arm64 arm64_32` matching the
watch app, and it registers with watchOS immediately (see below).

What to check once it installs: add each family, start a break, watch the
countdown, confirm the count goes up when the break ends.

### 7. Watch sync between simulators

`DEVELOPMENT.md` says `isReachable` can stay false on a paired, connected
simulator pair. Application context may still get through. Nobody has checked.

### 8. Firestore rules have no automated tests

See `DEVELOPMENT.md` → "Rules tests (not set up)".

---

## Done

**Background sync works on real hardware** (2026-11-21). Edited on the watch with
the phone app closed; the edit was there when the phone app opened, name and all.

---

## Tip: don't trust the watch face picker

A complication that is missing and one that never registered look the same there.
Ask watchOS instead:

```
xcrun simctl spawn <watch-sim-udid> pluginkit -mAv -p com.apple.widgetkit-extension
```

`com.lmunck.NSSB.watchkitapp.complications` shows up the moment the watch app is
installed. Checked this way on 2026-11-21 against a clean watchOS 27 simulator —
it registered immediately, which is what cleared the code and pointed at #2.

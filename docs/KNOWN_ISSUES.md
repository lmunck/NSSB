# Known issues

Eight. **One wants a two-minute check** (#1). The rest are handled, limits to
live with, or unchecked corners.

| # | Issue | Needs |
|---|---|---|
| 1 | Complication shows up; behaviour unchecked | **a 2-min check** |
| 2 | Watch never gets the new watch app | nothing now |
| 3 | App Group on a fresh machine | you, once |
| 4 | Phone edits reach the complication late | nothing |
| 5 | `breaks` can only grow | nothing |
| 6 | One warning on CI | nothing |
| 7 | Watch sync between simulators | a check |
| 8 | Firestore rules untested | a test suite |

---

## Needs you

### 1. The complication is installed but its behaviour is unchecked

**Done** (2026-11-24) — it is on the watch and appears in the watch face picker
under **NSSB**, listed as "Non-Smoking Breaks".

**Not done** — in this order: add it in each family (circular, rectangular,
inline, corner), start a break, watch the countdown run, then confirm the count
goes up when the break ends.

**Why it is worth the two minutes** — those four views have never been drawn by
watchOS, only by SwiftUI previews. The countdown depends on
`ProgressView(timerInterval:)` and `Text(timerInterval:)` animating themselves
without an entry per second, and the roll-over depends on `getTimeline`
scheduling an entry at break end. Both are reasonable; neither has been seen.

---

## Handled, but worth knowing

### 2. A watch app whose version never changes is not re-pushed

**What** — every build of the watch app is `1.3 (1)`. `CURRENT_PROJECT_VERSION`
and `MARKETING_VERSION` are hardcoded in all eight build configurations.

**Why it mattered** — iOS reads those two numbers to decide whether the copy on
the watch is stale. The watch app that gained a complication on 2026-11-21 looked
identical to the one already installed, so iOS left the old one alone. The old
copy worked fine; it simply had no `PlugIns/` inside it. Restarting the watch
re-registered the same complication-free bundle, which is why that appeared to
rule the complication out when it had never been installed at all.

**Why it is handled** — the watch is now a development device, and Xcode installs
the watch app directly without consulting version numbers. See the install recipe
below.

**Still true** — the fixed version numbers are unchanged, so this returns for
anyone installing through the iPhone's Watch app. Bump the build number, or
delete the app from the watch first.

### 3. The App Group has to exist in the developer account

`group.com.lmunck.NSSB`, on the watch app and on `NSSBComplications`. Done and
verified on this machine (2026-11-21) — signing in to Xcode was enough, automatic
signing made profiles carrying the group. Only a step again on a fresh account or
machine, and only if a device build fails on provisioning: add it under Signing &
Capabilities.

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

### 7. Watch sync between simulators

`DEVELOPMENT.md` says `isReachable` can stay false on a paired, connected
simulator pair. Application context may still get through. Nobody has checked.

### 8. Firestore rules have no automated tests

See `DEVELOPMENT.md` → "Rules tests (not set up)".

---

## Done

- **Background sync on real hardware** (2026-11-21). Edited on the watch with the
  phone app closed; the edit was there when the phone app opened, name and all.
- **Complication installed and offered by the picker** (2026-11-24), after the
  watch was paired as a development device.
- **The watch is a development device**, so installs no longer go through the
  iPhone.

---

## Tip: "mismatched platform" is not a problem

Xcode says this about a device that does not match the **selected scheme**. With
the iOS `NSSB` scheme active, the watch is listed as incompatible; with
`NSSB WatchKit App` active, the iPhone is, in the same words. Switch the scheme.

Ask instead of guessing:

```
xcodebuild -showdestinations -scheme "NSSB WatchKit App" -project NSSB.xcodeproj
```

## Tip: installing on the watch from the command line

Get the watch's UDID from `xcrun devicectl list devices`, then:

```
xcodebuild -project NSSB.xcodeproj -scheme "NSSB WatchKit App" \
  -destination 'id=<watch-udid>' -configuration Debug \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
```

The two provisioning flags matter the first time: a newly trusted watch is in no
profile yet, and without them the build fails with "doesn't include the currently
selected device". They register it and reissue both profiles. Then:

```
xcrun devicectl device install app --device <watch-udid> \
  ~/Library/Developer/Xcode/DerivedData/NSSB-*/Build/Products/Debug-watchos/NSSB.app
```

Check `PlugIns/NSSBComplications.appex` is inside that bundle before installing.

## Tip: don't trust the watch face picker

A complication that is missing and one that never registered look the same there,
and the picker lists it under the app name (**NSSB**), not under
"Non-Smoking Breaks". On a simulator, ask watchOS directly:

```
xcrun simctl spawn <watch-sim-udid> pluginkit -mAv -p com.apple.widgetkit-extension
```

`com.lmunck.NSSB.watchkitapp.complications` appears the moment the watch app is
installed. Checked this way on 2026-11-21 against a clean watchOS 27 simulator —
it registered immediately, which cleared the code and the bundle and pointed at #2.

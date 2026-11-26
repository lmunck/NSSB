# Known issues

Six, and **none of them blocks anything**. One is worth a glance, three are
limits to live with, two are corners nobody has checked.

The watch path is no longer among them: background sync, the complication
installing, rendering, counting down through a real break and rolling the count
over at the end are all verified on hardware (2026-11-21 to 2026-11-24). Those
entries are deleted rather than kept as history — `git log docs/KNOWN_ISSUES.md`
has the record if it is ever wanted.

| # | Issue | Needs |
|---|---|---|
| 1 | Two complication families never drawn | a glance |
| 2 | Phone edits reach the complication late | nothing |
| 3 | `breaks` can only grow | nothing |
| 4 | One warning on CI, not ours | nothing |
| 5 | Watch sync between simulators | a check |
| 6 | Firestore rules untested | a test suite |

---

## Worth a glance

### 1. Two of the four complication families have never been drawn

`accessoryCircular` and `accessoryRectangular` were tested on a watch face
through a real break and behaved. `accessoryInline` and `accessoryCorner` have
not been on a face at all; until 2026-11-26 `accessoryInline` had not even had a
preview.

What is left is layout, not mechanism: all four share the `timerInterval` views
and the same `getTimeline` schedule, and those are the parts that were in doubt.
Worst case is a clipped label in `accessoryInline` or `accessoryCorner`.

All four now have a `#Preview` in `NSSBComplications.swift`, each including
`BreakEntry.placeholderCrowded` — twelve breaks and a savings figure with
decimals, the state with the most to fit. **Look at the inline one first.** Its
unlit label is `"12 non-smoking breaks"` plus an icon, by some distance the
longest string the extension asks a family to hold, and `accessoryInline` is one
short line that gets narrower the smaller the watch. It has deliberately not
been shortened: nobody has seen it truncate, and shortening it now would answer
a guess and leave the glance with nothing to compare against.

**This cannot be settled from a session on this machine.** The complication
installs and registers on a watch simulator (`pluginkit` confirms it, and the
watch app builds and installs clean), but nothing can put it on a face:
`DEVELOPMENT.md` → "Looking at the views" has what was tried. It needs Xcode
previews or a watch, both of which are a minute's work for whoever has one in
front of them.

---

## Design limits — nothing to do

### 2. Phone edits reach the complication late

Application context reaches the watch when the watch app next runs. A phone-side
`transferCurrentComplicationUserInfo` would push sooner, if that ever matters.

### 3. `breaks` can only grow

Merging two devices is a union, so a break can never be removed. Fine while
nothing deletes breaks. A future reset feature needs a tombstone or a reset epoch.

### 4. One warning on CI, and it is not ours

"Metadata extraction skipped. No AppIntents.framework dependency found." Not the
project's code — Xcode's AppIntents metadata step, which the app does not use.

This entry used to list two. The other was `PresenceRepository.swift:973`, "no
'async' operations occur within 'await' expression", and it was the project's
own: the departure timer's `Task` already ran on the main actor, so the `await`
marked a hop that never happened. Dropped in 81de278, and the warning went with
it. Checked on the green `main` run of 2026-11-25, where the AppIntents line is
the only `warning:` left, so `DEVELOPMENT.md`'s claim that the project builds
without warnings of its own is now true rather than nearly true.

---

## Not checked yet

### 5. Watch sync between simulators

`DEVELOPMENT.md` says `isReachable` can stay false on a paired, connected
simulator pair. Application context may still get through. Nobody has checked.

### 6. Firestore rules have no automated tests

See `DEVELOPMENT.md` → "Rules tests (not set up)".

---

## Setup: the App Group

`group.com.lmunck.NSSB`, on the watch app and on `NSSBComplications`. Without it
the complication cannot be fed, and `SharedContainer` logs exactly that rather
than failing quietly.

Signing in to Xcode is enough on a machine that is already set up — automatic
signing makes profiles carrying the group. Only a real step on a fresh account,
and only if a device build fails on provisioning: add it under Signing &
Capabilities.

## Trap: "mismatched platform" is not a problem

Xcode says this about a device that does not match the **selected scheme**. With
the iOS `NSSB` scheme active, the watch is listed as incompatible; with
`NSSB WatchKit App` active, the iPhone is, in the same words. Switch the scheme.

Ask instead of guessing:

```
xcodebuild -showdestinations -scheme "NSSB WatchKit App" -project NSSB.xcodeproj
```

## Trap: installing on the watch

**Every build of the watch app is `1.3 (1)`** — `CURRENT_PROJECT_VERSION` and
`MARKETING_VERSION` are hardcoded in all eight configurations. iOS reads those to
decide whether the copy on the watch is stale, so a watch app that gained a
complication looks identical to the one already installed and is never replaced.
The old copy keeps working, which is what makes this so slow to spot. Restarting
the watch does not help.

Pairing the watch as a development device avoids it, because Xcode installs
directly. Get the UDID from `xcrun devicectl list devices`, then:

```
xcodebuild -project NSSB.xcodeproj -scheme "NSSB WatchKit App" \
  -destination 'id=<watch-udid>' -configuration Debug \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
```

The two provisioning flags matter the first time: a newly trusted watch is in no
profile yet, and without them the build fails with "doesn't include the currently
selected device" on a device Xcode can see perfectly well. Then:

```
xcrun devicectl device install app --device <watch-udid> \
  ~/Library/Developer/Xcode/DerivedData/NSSB-*/Build/Products/Debug-watchos/NSSB.app
```

Installing through the iPhone's Watch app instead means deleting the watch app
first, or bumping the build number.

## Trap: don't trust the watch face picker

A complication that is missing and one that never registered look the same there,
and it is listed under the app name (**NSSB**), not under "Non-Smoking Breaks".
On a simulator, ask watchOS directly:

```
xcrun simctl spawn <watch-sim-udid> pluginkit -mAv -p com.apple.widgetkit-extension
```

`com.lmunck.NSSB.watchkitapp.complications` appears the moment the watch app is
installed.

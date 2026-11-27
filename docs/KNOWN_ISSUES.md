# Known issues

Ten. **Nothing here stops the app working**, but four of them stand between
it and other people's phones: one is worth a glance, three are limits to live
with, two are corners nobody has checked, and four came out of a readiness
survey on 2026-11-27 and are about shipping rather than about the code.

The watch path is no longer among them: background sync, the complication
installing, rendering, counting down through a real break and rolling the count
over at the end are all verified on hardware (2026-11-21 to 2026-11-24). Those
entries are deleted rather than kept as history — `git log docs/KNOWN_ISSUES.md`
has the record if it is ever wanted.

| # | Issue | Needs |
|---|---|---|
| 1 | The inline label at two digits | a glance |
| 2 | Phone edits reach the complication late | nothing |
| 3 | `breaks` can only grow | nothing |
| 4 | One warning on CI, not ours | nothing |
| 5 | Watch sync between simulators | a check |
| 6 | Firestore rules untested | a test suite |
| 7 | Nothing explains the courtyard | an onboarding pass |
| 8 | One accessibility label in the whole app | a VoiceOver pass |
| 9 | No Firebase App Check | a config change |
| 10 | The `stats` function is not in this repo | finding out |

---

## Worth a glance

### 1. The inline label has never been seen at two digits

All four families were looked at on an Apple Watch Ultra 3 through a live
break on 2026-11-27, which closes the old entry here: `accessoryInline` and
`accessoryCorner` lay out correctly, nothing clipped, and the corner gauge
curves where it should.

What that glance could not cover is the one string that needs two digits.
`"12 non-smoking breaks"` plus an icon is the longest thing the extension asks
a family to hold, and `accessoryInline` is one short line that gets narrower
the smaller the watch. The wrist it was looked at on had a single-digit count,
which proves nothing about the long one, and nobody is going to smoke ten
cigarettes to find out. `BreakEntry.placeholderCrowded` is in every `#Preview`
for exactly this; an Xcode preview on the smallest watch settles it in a
minute. It has deliberately not been shortened — shortening it now would
answer a guess.

The same glance also killed the drawn cigarette, which read as a progress bar
on a face: `docs/ARCHITECTURE.md` → "Why not a drawn cigarette" has that.

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

## Before other people have it

Four things found by reading the project through on 2026-11-27 with the
question "could this go to testers tomorrow". None of them is a bug.

### 7. Nothing explains the courtyard

There is no onboarding, no first-run anything. The courtyard — asking the
whole yard for a light rather than a person, waiting for company, what the
anonymity actually guarantees — is the most distinctive thing the app does
and the least self-evident. Handed to a tester cold, it produces feedback
about confusion instead of feedback about the idea.

### 8. One accessibility label in the whole app

`grep -rn accessibilityLabel` returns a single hit. The primary control is a
drawn cigarette with no text anywhere near it, so VoiceOver has nothing to
say about the main screen. Not a submission blocker; it is an exclusion.

### 9. No Firebase App Check

Auth is anonymous and the API key ships inside the binary, as it must, so
anyone who pulls the key can mint a token and write to the courtyard. The
rules in `firebase/firestore.rules` are what keeps that bounded — durations
capped, impersonation blocked by a per-break `ownerHash`, races settled
server side, litter collectable by anyone — so the worst case is junk
documents and the bill for them rather than anything lost. App Check is the
standard answer and is worth having before a public link exists.

### 10. The `stats` function is not in this repo

`firestore.rules` says `/stats/{document}` is "written by a scheduled
function, never by a client", and `firebase/` has no `functions/`. Either it
is deployed out of band and undocumented, or nothing writes the collection
and whatever reads it gets nothing. Nobody has checked which.

### Two small ones that are not worth an entry

`ITSAppUsesNonExemptEncryption` is not set anywhere, so every upload stops to
ask about export compliance; one key in `NSSB/Info.plist` ends that. And
there is no string catalogue — the app is English, which is fine as a
decision and less fine as an oversight.

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

**The build number is hardcoded, so bump it when a build has to replace one.**
`CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` are literals in
`project.pbxproj` — nothing derives them from the build. iOS reads them to decide
whether the copy on the watch is stale, so two builds carrying the same numbers
are the same build as far as it is concerned: a watch app that gained a
complication looks identical to the one already installed and is never replaced.
The old copy keeps working, which is what makes this so slow to spot. Restarting
the watch does not help.

It is `1.3 (2)` as of 2026-11-27, raised from `(1)` for the iOS app, the watch
app and `NSSBComplications` together — App Store Connect wants the embedded watch
app and its extension to agree, so they move as a set and `NSSBTests` keeps its
own. Raise it again whenever a build is meant to land on a watch through the
iPhone's Watch app.

**What it looks like when it bites.** On 2026-11-27 the complication drew today's
count on every family during a live break, with no cigarette and no countdown.
That is exactly what the current code draws when `breakStarted` is nil in the
snapshot, so it reads as a sync or App Group fault and sends you into the data
path — where everything is fine, because the extension running on the watch is
simply an older one. Before suspecting the data, check which build is installed.

`devicectl` never asks the question, so a direct install is the way out:

```
xcrun devicectl device install app --device <watch-udid> <path-to>/NSSB.app
```

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

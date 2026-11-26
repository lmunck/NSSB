# Working on NSSB

## Building and testing

Two schemes and one test target.

```
xcodebuild -project NSSB.xcodeproj -scheme NSSB \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build

xcodebuild -project NSSB.xcodeproj -scheme "NSSB WatchKit App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 12 (46mm)' build

xcodebuild test -project NSSB.xcodeproj -scheme NSSB \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

### The live checks

Three tests in `NSSBTests/LiveSynchronyTests.swift` drive the real Firestore
service against the real project, with the second person played by a second
anonymous client over the REST API. They are skipped unless asked for by
name, because they need the network and write real documents:

```bash
TEST_RUNNER_NSSB_LIVE=1 xcodebuild test -project NSSB.xcodeproj -scheme NSSB \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -only-testing:NSSBTests/LiveSynchronyTests
```

The `TEST_RUNNER_` prefix matters: xcodebuild does not pass its own
environment to the test process, it forwards variables with that prefix and
strips it. A plain `NSSB_LIVE=1` skips all three and still reports success.

They exist because the stand-in service has never rejected a write and the
real one has - silently. `setData(from:)` only throws on encoding failures,
so a document the rules refused still looks like a success, still comes back
from the local cache and still fills the first snapshot. Anything that writes
to Firestore should be checked against the server, never against the screen.


Both schemes are shared (`xcshareddata/xcschemes`) and the `NSSB` test action
runs `NSSBTests`, so the commands above work on a fresh clone without Xcode
having to generate anything first. Both have to be shared: once one scheme is,
`xcodebuild` stops generating the others. Building `NSSB WatchKit App` also
builds the `NSSBComplications` extension it embeds.

### CI

`.github/workflows/build.yml` runs the same builds (unsigned, generic
simulator destinations), checks that `NSSBComplications.appex` is inside the
watch app, and runs `NSSBTests` on the first available iPhone simulator, on
every pull request and every push to `main`. It never sets
`TEST_RUNNER_NSSB_LIVE`, so the live checks stay skipped there.

The runner renders several times slower than this machine, which used to
fail the film test about half the time. It no longer does; see "A journey
has to outlast the camera" below before changing anything that times out
there.

The project builds with no warnings of its own. If you add one, it is yours.

### What the tests cover

They cover the things that are hard to notice going wrong:

- **Naming** — that a generated name is always two capitalised words that parse
  back as a pool name, that re-rolling one wheel leaves the other alone, that a
  re-roll is never a no-op, and that the vocabulary never again contains the
  words the old general-English noun list did.
- **Presence** — burn position and clamping, `isLive` flipping exactly at
  `endsAt`, "06:41 there" using their offset rather than ours, and that a
  republished break keeps its id and end time so it cannot be duplicated or
  extended.
- **CigDesign encoding** — that data written before `CodableColor` existed
  still decodes, and that the keys and colour shape have not drifted. This one
  matters most: `CigDesign` is a wire format for the saved file, watch sync,
  share URLs and Firestore.
- **Break statistics** — that a cigarette still burning is not yet counted,
  and that an empty history does not produce NaN.
- **Asking for a light** — the document (eight seconds, lowercase-hex asker
  hash, open until claimed or expired, the giver's burn position surviving the
  wire) and the state machine driven end to end against
  `SimulatedPresenceService`: a light arriving at the last moment is not
  thrown away by the timeout, lighting your own takes the ask down, an
  answered ask leaves no document behind, and only the first light counts.

`BreakAsk.window` is a `var` for the same reason `Date.breakLength` is one —
so the eight seconds can be tested without a test spending eight seconds.
Nothing in the app assigns to it.

## Simulators

Phone and watch must be paired for WatchConnectivity to do anything. The
pairing is per-machine, not in the repository:

```
xcrun simctl pair <phone-udid> <watch-udid>
xcrun simctl list pairs
```

Both devices have to be booted for the pair to show `(active, connected)`.
Without it, `session.isReachable` is always false and sync silently does
nothing - which is why phone/watch sync went unverified for a long time.

An active, connected pair is necessary but apparently not sufficient: as of
this writing both apps run in the foreground on a paired, connected pair and
`isReachable` is still false in both directions, so nothing crosses — neither
the data sync nor the "somebody gave you a light" haptic. Both are written
against the same `WCSession`, so when one works the other does. On a real
phone and watch this is the normal case; between simulators it is a coin
toss.

## Looking at the views

The simulator's automation panel does not work on this machine. It fails with
`Failed to initialize simulator device set`, because it goes looking for a
CoreSimulator framework at a path Xcode 27 no longer uses — Xcode 27 moved the
simulator into `Xcode.app/Contents/Applications/DeviceHub.app` and dropped
`Contents/Developer/Applications` entirely. So there is no way to tap through
the app from a session and watch what happens. `xcrun simctl` still boots,
installs, launches and screenshots; it just cannot tap.

And `DeviceHub.app` itself opens no window here: it runs as an agent process
with no window and no menu bar, so there is nothing to click. A watch simulator
boots, takes an app and answers `pluginkit` perfectly well without it — what
cannot be done is the one thing a watch face needs, which is tapping through
Edit to put a complication in a slot. So the complication's four layouts cannot
be checked from a session on this machine at all, only in Xcode previews or on a
watch (`docs/KNOWN_ISSUES.md` → issue 1).

The watch face's own store looks like a way round it and is not. The selected
face is plain JSON at

```
~/Library/Developer/CoreSimulator/Devices/<watch-udid>/data/Library/NanoTimeKit/
  CollectionStores/GlobalStores/LibraryFaces/Faces/<face-uuid>/face.json
```

and a face with complications in it would name them there. But the key names for
slots are undocumented, the face bundle ids are internal codenames, and
NanoTimeKit drops a complication descriptor it does not recognise — which leaves
an empty slot, which is indistinguishable from a complication that drew nothing.
That is the same trap as "don't trust the watch face picker" in
`docs/KNOWN_ISSUES.md`, one layer down: a guess that half works cannot be told
from a view that is broken, so the answer it gives is worth nothing. Don't spend
the afternoon.

Several drawing bugs were fixed blind before this was addressed, including a
companion that was correctly placed and completely invisible. Two harnesses
in `NSSBTests` close most of that gap. Neither replaces using the app.

### RenderTests — still pictures

`ImageRenderer` draws a view once, with nothing running: no `onAppear`, no
`task`, no timers. It answers "is it there, and where", and nothing about
motion. Views that animate themselves into place therefore render in their
starting position, which is why `BesideYouView` takes a `settled` flag — the
app never passes it, the harness does.

It draws through the app's own views rather than rebuilding the arrangement.
An earlier version assembled the overlay by hand, which made the harness a
second implementation of the thing it was meant to be checking, and a second
implementation cannot catch a mistake in the first.

```
xcodebuild test -scheme NSSB \
  -destination 'platform=iOS Simulator,id=<udid>' \
  -only-testing:NSSBTests/RenderTests
```

It prints the directory it wrote into and the sides the model chose, so the
picture can be checked against the thing that decided it.

### LiveViewTests — film

Puts the view in a real `UIWindow` with a real runloop, lets time pass, and
photographs it. This is the only way to see an arrival actually arrive, or to
catch something that appears correctly and then vanishes.

Five things about it are easy to get wrong, and the first two cost an evening
each:

- **Capture.** `drawHierarchy(in:afterScreenUpdates:)` comes back black in a
  test bundle. Render the layer tree instead.
- **Layout.** A view added after the window was shown never gets a layout
  pass on its own here, and its overlay renders as nothing — which looks
  exactly like the bug you are hunting. Call `setNeedsLayout` and
  `layoutIfNeeded` on the root view before every frame.
- **Frame rate.** Render at `scale = 1`. At the device's own scale a
  phone-sized window costs about a second a frame, which is slower than the
  animation being filmed, and a film at one frame a second cannot tell a walk
  from a jump.
- **Measure afterwards.** Working out where somebody is costs about another
  second a frame in a debug build. Capture the whole film into `[UIImage]`
  first and measure it once it is over, or the measuring sets the frame rate.
- **A journey has to outlast the camera.** See below; this one cost a week of
  CI going red about half the time.

With those, a film runs at roughly four frames a second — enough to catch a
cigarette part of the way over, which is the only thing that distinguishes one
view moving from one view being replaced by another.

Two measures. `brightness` gives how much of each vertical third of the frame
is not black, so "somebody is on the left and somebody is on the right" fails
the test rather than waiting for a person to notice a picture. `whereabouts`
subtracts the frame with nobody in it and reports where what is left sits, how
far across it reaches, and how much of it there is — your own cigarette is in
the middle of the screen and outweighs everybody, so it has to be taken away
rather than worked around.

### A journey has to outlast the camera

How fast the film runs is the machine's business. How long the journey takes
is ours, and only the ratio of the two decides whether the walk can be
photographed at all.

The journey's phases are tenths of a second: leaning over takes 0.78s. Film
that at four frames a second and three or four frames land inside it. Film it
on a runner that renders half as fast and one does — and one frame in the
middle of a walk is indistinguishable from a walk that never happened, which
is the exact bug `testTheWalkOverNeverBlinks` exists to catch. So it failed
about half of all CI runs, on code that was correct, including on a commit
that changed only Markdown.

The fix is `VisitorCigaretteView.pace`, which multiplies every duration in
the journey — the animation curves and the pauses between phases together,
or the two drift apart. It is 1 in the app and nothing in the app assigns to
it, for the same reason `BreakAsk.window` is a var. The film test sets it to
3, so leaning over takes 2.34s and a slow machine still gets several frames
inside it.

Measured on this machine by widening the gap between frames to stand in for a
slower renderer, with the runner's own figures read off the `test-log`
artifact of a green run:

| seconds per frame | frames in the walk | caught part way in | verdict |
|---|---|---|---|
| 0.17 (this machine) | 23 | 10 | passes |
| 0.24 (the CI runner) | 19 | 6 | passes |
| 0.64 | 5 | 3 | passes |
| 0.91 | 4 | 2 | passes |
| 1.16 | 3 | 2 | fails, and says why |

The test needs two frames caught part way in. The runner turns out to be
only about a third slower than this machine rather than the several times
the old failures suggested — 0.78s was simply too short for either of them
to photograph reliably, and the runner lost the toss about half the time.
With the journey stretched, the test holds to roughly five times slower than
this machine. Past that it fails on a separate check — "the film is too
sparse to tell a walk from a jump" — so a machine too slow to answer the
question says so instead of blaming the view. If that ever fires, raise
`pace`. Do not lower the counts: they are the difference between somebody
walking and somebody teleporting.

The runner's numbers are not on the console: the workflow pipes test output
through a `grep`, so the lines the film prints are in the uploaded
`test-log` artifact rather than in the job log.

The film also runs until the arrival is over rather than for a fixed number
of frames, because a fixed count is a fixed amount of the machine's time and
not a fixed amount of the journey.

### One view per person

`testTheWalkOverNeverBlinks` exists because of a bug worth not having twice.
Somebody coming over used to be drawn by three views in turn: a cigarette at a
courtyard position, a handoff in a different coordinate space with a different
renderer, and then a companion that appeared afterwards. Each handover was a
frame with nobody in it followed by a cigarette of a different size in a
different place, and from the outside that is three arrivals rather than one.

So: one view per person, held by name, from the courtyard to the end of their
cigarette (`Visitor` / `BesideYouView`). When a handoff ends, that person's
`handoff` goes nil and nothing else about them changes, so SwiftUI keeps the
same view and it carries on moving. `onSettled` is called as the last movement
*begins* rather than after it, so the state behind the view can catch up
without interrupting anything.

Animations go on `.animation(_:value:)` rather than in `withAnimation`. A
`withAnimation` that runs while SwiftUI is still settling a newly inserted view
gets swallowed, and a swallowed arrival is indistinguishable from somebody who
teleported — which is exactly how this was first reported.

### Writing the files out

Both harnesses write into `NSTemporaryDirectory()`, which for a simulator is
a real directory on the Mac, and print the path. They deliberately do **not**
take a path through the environment: `xcodebuild` only forwards variables
prefixed `TEST_RUNNER_`, and one that does not arrive looks exactly like the
tests passing. This project has been bitten by that before — see the live
Firebase checks below.

## Firebase

See `firebase/README.md`. Short version: the app runs without any of it, on a
simulated presence service, until a `GoogleService-Info.plist` and the Firebase
package are both present.

### Rules tests (not set up)

`firebase/firestore.rules` is load-bearing and currently has no automated
tests. The standard approach is `@firebase/rules-unit-testing` against the
Firestore emulator, but the emulator needs a Java runtime and this machine has
none. Installing a JDK is the only blocker.

Until then, a rules change is verified against the live project instead, which
is less convenient but not much weaker: sign in anonymously two or three times
over the Identity Toolkit REST API, write scratch documents with the Firestore
REST API using those tokens, check that each write is allowed or refused as the
rule says, and delete them again. The `asks` rules were checked this way — a
hash that is not yours, an ask born answered, a twenty-second ask, answering
your own ask, a second person answering one that is already answered, and
deleting somebody else's fresh ask are all refused; the first answer and the
owner's own delete are allowed.

**Do not conclude a write worked because the app looked happy.** `setData(from:)`
only throws if *encoding* fails: a rejected write still goes to the local cache,
the listener attaches, and the first snapshot comes back from that same cache
with the document in it. Both devices showed each other while the server held
nothing. Every write in `FirestorePresenceService` therefore encodes first and
then awaits the untyped `setData` / `updateData`, and anything being verified is
read back from the **server**, not from a screen.

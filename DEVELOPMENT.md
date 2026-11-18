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


The `NSSB` scheme is shared (`xcshareddata/xcschemes`) and its test action runs
`NSSBTests`, so the command above works on a fresh clone without Xcode having
to generate anything first.

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

Several drawing bugs were fixed blind before this was addressed, including a
companion that was correctly placed and completely invisible. Two harnesses
in `NSSBTests` close most of that gap. Neither replaces using the app.

### RenderTests — still pictures

`ImageRenderer` draws a view once, with nothing running: no `onAppear`, no
`task`, no timers. It answers "is it there, and where", and nothing about
motion. Views that animate themselves into place therefore render in their
starting position, which is why `CompanionCigaretteView` takes an `arrived`
flag — the app never passes it, the harness does.

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

Two things about it are easy to get wrong and cost an evening each:

- **Capture.** `drawHierarchy(in:afterScreenUpdates:)` comes back black in a
  test bundle. Render the layer tree instead.
- **Layout.** A view added after the window was shown never gets a layout
  pass on its own here, and its overlay renders as nothing — which looks
  exactly like the bug you are hunting. Call `setNeedsLayout` and
  `layoutIfNeeded` on the root view before every frame.

The assertions are on how much of each vertical third of the frame is not
black, so "somebody is on the left and somebody is on the right" fails the
test rather than waiting for a person to notice a picture.

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

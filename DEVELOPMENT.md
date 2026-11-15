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

## Firebase

See `firebase/README.md`. Short version: the app runs without any of it, on a
simulated presence service, until a `GoogleService-Info.plist` and the Firebase
package are both present.

### Rules tests (not set up)

`firebase/firestore.rules` is load-bearing and currently has no automated
tests. The standard approach is `@firebase/rules-unit-testing` against the
Firestore emulator, but the emulator needs a Java runtime and this machine has
none. Installing a JDK is the only blocker; until then, rules changes are
verified by deploying them and exercising the real app against the real
project, which catches behaviour but not edge cases.

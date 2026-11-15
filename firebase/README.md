# Firebase setup

The code is written and compiles without any of this. Until the steps below
are done the app runs on `SimulatedPresenceService` and behaves exactly as it
did before — nothing is sent anywhere.

Three of these steps need a Google account, so they have to be done by hand.

## 1. Create the project

In the [Firebase console](https://console.firebase.google.com):

- New project, no Google Analytics needed.
- Add an iOS app with bundle id `com.lmunck.NSSB`.
- Download `GoogleService-Info.plist` and drop it into the `NSSB` target.

`FirebaseApp.configure()` only runs when that file is present, so adding it is
what switches the app from the simulated service to the real one.

## 2. Add the SDK

In Xcode: File → Add Package Dependencies →
`https://github.com/firebase/firebase-ios-sdk`

Add these three products to the **NSSB** target only — not the watch target,
which has no presence of its own yet:

- `FirebaseAuth`
- `FirebaseFirestore`
- `FirebaseCore`

`FirestorePresenceService.swift` is wrapped in `#if canImport(FirebaseFirestore)`,
so it compiles to nothing until the package is there and lights up by itself
once it is.

## 3. Turn on anonymous auth

Console → Authentication → Sign-in method → Anonymous → Enable.

Anonymous only. Nothing in a presence document identifies a person beyond a
country code and a cigarette they rolled themselves, and it should stay that
way.

## 4. Deploy the rules and the index

```
cd firebase
firebase use --add          # pick the project you just created
firebase deploy --only firestore:rules,firestore:indexes
```

`firebase.json` in this folder is what points the CLI at the two files, and
`firebase use --add` writes a `.firebaserc` with the project id.

`firestore.rules` is the interesting file. It enforces the parts of the design
that must not be left to the client:

- you may only publish as yourself
- a break cannot last longer than six minutes, be backdated, or be scheduled
- a published break is immutable — no update rule exists at all, so a name
  cannot be swapped mid-break
- `stats/` is written by a scheduled function and never by a client

## 5. Document cleanup (no TTL)

**There is no TTL policy on this project, and that is deliberate.**

Firestore TTL requires the Blaze plan — the API refuses with
`PERMISSION_DENIED: Project has billing disabled`. Neither the Google Cloud
console nor `gcloud` can set one on Spark, so this is not an oversight you can
click your way out of.

The app cleans up after itself instead, in three places:

| when | what happens |
|---|---|
| cigarette burns out | `breakEnded()` deletes the document |
| break cancelled | same path, same delete |
| app killed mid-break | the break id is persisted, and the next launch deletes it |

The third case is the one TTL would normally cover. `PresenceRepository`
stores the live break's document id in `@AppStorage`, and only clears it after
a *successful* delete — so a failed cleanup retries on the next launch rather
than leaking the document.

What is left uncovered: a break whose app is killed and then never opened
again. That document stays until someone adds a TTL policy. It is invisible
either way, because every reader filters `endsAt > now`, so this is a storage
question rather than a correctness one.

If the project ever moves to Blaze, this is the whole job:

```
gcloud firestore fields ttls update endsAt --collection-group=presence --enable-ttl
```

(`--database` defaults to `(default)`, despite the synopsis listing it as
required.) Allow ten minutes or more for the policy to become active.

## Costs

Reads are the only thing worth watching. The design keeps them bounded:

- the courtyard query is capped at 20 documents
- the listener is attached when a break starts and detached when it ends,
  never left running on a background screen
- the live count comes from a single `stats/live` document written by a
  scheduled function — never from counting the collection

A five-minute break is a handful of reads. Counting the collection on every
open would be the one thing that turns this into a bill.

# Architecture

This covers the parts that aren't the courtyard: the saved data, phone ⇄ watch sync, the complication and logging. For the courtyard (presence, asks, waits) the code in `NSSB/Logic/Presence/` is the reference, with `firebase/README.md` and `firebase/firestore.rules` for the backend side. For build and test mechanics, see `DEVELOPMENT.md`.

## State stores

Each app has one `ObservableObject` that is at once the state store, the persistence trigger and the sync engine: `WCSessionPhone` (iOS) and `WCSessionWatch` (watchOS). Views get a `Binding<NonSmokingData>` and mutate it directly. Every mutation runs `didSet`, which:

1. **stamps** the change: `data.touch(ifChangedFrom: oldValue)` sets `lastUpdate = .now` only if content changed and the value doesn't already carry an arriving stamp. `lastUpdate` means *when this last changed, on the device that changed it*, never *when it was sent*;
2. **saves**: the watch saves every change. The phone saves breaks and name changes at once, and colour/width changes on scene-phase changes, so slider drags don't write every frame;
3. on the watch, **refreshes the complication** (`SharedContainer.write`);
4. **sends** (`sendUpdate`).

The two classes are deliberately parallel. A change to the sync logic in one almost always belongs in the other.

## Data model

`NonSmokingData` (`Shared/Models/NonSmokingData.swift`) is the saved file and the watch payload:

| Field | Meaning |
|---|---|
| `breaks: [Date]` | Start times of completed breaks |
| `breakStarted: Date?` | The break in progress |
| `costPer20: Double` | Price of 20 cigarettes |
| `accentHue: Int?` | Legacy accent hue |
| `cigDesign: CigDesign` | The cigarette, including its name |
| `lastUpdate: Date` | When this last changed (see stamping above) |

Who you are smoking with is deliberately *not* in here. See `BreakCompany` under phone ⇄ watch sync.

**Wire formats.** `NonSmokingData` and `CigDesign` decode field by field with defaults, so a missing or unreadable field never fails the whole file. `CigDesign` is also the share-link payload and part of Firestore documents. Its colours go through `CodableColor`, which has exactly the shape the old `Color: Codable` produced. `CigDesignCodableTests` and `NonSmokingDataCodableTests` pin both formats. When you add a field, add it to `CodingKeys` and to `init(from:)`.

## Persistence

`Shared/Logic/CodingFunctions.swift` writes JSON to `Documents/userData`.

- **No file:** first launch or an upgrade from v1, which kept `cigDates` and `costPer20` in `UserDefaults["smokeData"]`. That data is converted.
- **Unreadable file:** moved aside to `userData-unreadable-<unix time>`, and `load()` returns `nil`. It never falls back to the v1 data, which would replace the whole history.

## Phone ⇄ watch sync

Two channels carry the same JSON payload.

- **Live message:** `sendMessageData` with a reply, only while the other app is reachable. The reply is the receiver's merged state, which is logged and compared, not applied.
- **Application context:** `updateApplicationContext(["nonSmokingData": …])` on every send while the counterpart app is installed. The system keeps only the latest and delivers it in the background when the other app next runs. On activation each side first merges any pending `receivedApplicationContext`, then offers its own state.

A copy that equals the last thing received is never sent back. Both channels end in `receivedUpdate` → `NonSmokingData.merge(from:)`:

- `breaks`: union, de-duplicated and sorted. Deletions can't propagate, and today nothing deletes.
- `breakStarted`, `costPer20`, `accentHue`, `cigDesign`: the remote value wins only if the local copy is older by `lastUpdate`.

Separately, the phone sends two non-data events as plain `sendMessage`s.

- **`litByStranger`** taps the wrist when somebody in the courtyard answered your ask. Deliberately not queued: a late tap on the wrist would be wrong. See `WCSessionPhone.tellWatchYouWereLit`.
- **`company`** carries a `BreakCompany`: who is standing with you, their cigarette, when theirs was lit, and which side of you they are on. This one *is* queued — it also rides in the application context under `breakCompany` — because company is a state that lasts a whole cigarette rather than an event, and a watch raised mid-break should find the right people there. See `WCSessionPhone.tellWatchWhoIsWithYou`.

`BreakCompany` (`Shared/Models/BreakCompany.swift`) is not part of `NonSmokingData` and never saved: company lasts exactly as long as the cigarettes do and nothing about it is kept. It is not stamped and not merged either — only the phone has a courtyard, so only the phone ever writes one, and the watch takes its word. What stands in for the merge is that every companion carries the instant their own cigarette was lit and both sides filter on it, exactly as the courtyard filters on `BreakPresence.endsAt`: a payload delivered an hour late draws nobody. The watch adds one filter the payload cannot carry — nobody is drawn unless its own break is running — which covers the round trip after a break is stubbed out on the wrist.

The application context is built in one place (`WCSessionPhone.pushContext`) because the system keeps one dictionary: whatever a call leaves out is no longer waiting for the watch. So the data always goes in, even when only the company changed. Company goes in only when there is somebody out there; an absent key means nobody.

The watch draws this in `CompanyView`, as the last frame of the phone's journey and nothing before it — the walk over and the two tips touching are the phone's, and by the time a payload could arrive they are over. The courtyard itself stays on the phone.

## Complication (`NSSBComplications/`)

A WidgetKit extension embedded in the watch app.

- **Data:** the watch writes a trimmed snapshot (running break, breaks from the last 48 h, price, `cigDesign`) to the App Group `group.com.lmunck.NSSB` through `SharedContainer`. It reloads timelines only when that snapshot changed, because reloads are budgeted. The design travels because the complication draws the cigarette rather than a bar, and a cigarette coloured in Customize should look like itself on the wrist.
- **Timeline:** three entries - now, the moment a running break ends (the count goes up) and next midnight (it resets). Nothing in between, because nothing in between changes: `Text(timerInterval:)` and `ProgressView(timerInterval:)` are handed an interval and move on their own. A running break used to get sixty entries, one per step of a drawn cigarette burning down, because a drawing is the one thing WidgetKit will not animate for you.
- **Drawing:** the system's own progress views - a ring in `accessoryCircular`, a linear bar in `accessoryRectangular`, the bezel gauge in `accessoryCorner` - each given the break's interval and left to count itself down. `accessoryInline` has no room for one and shows the countdown as text. They are tinted `CigDesign.body`, the colour of the cigarette's paper.
- **Why not a drawn cigarette:** there was one, and on a watch face it read as a progress bar. A complication on a face is always tinted, which takes `CigDesign` out of it entirely and leaves a flat silhouette; at the size a complication gives you, a flat cigarette and a flat bar are the same picture. Reproportioning it did not save it. `git log` has the drawing if it is ever wanted - the colours would look right in the Smart Stack, which is the one place a complication is drawn in full colour.
- **Families:** `accessoryCircular`, `accessoryRectangular`, `accessoryInline`, `accessoryCorner`.
- **Compiled sources:** besides its own file, only `NonSmokingData`, `CigDesign`, `CodableColor`, the colour/date/calendar/sequence/string extensions, `Colors`, `Log` and `SharedContainer`. Anything those files start to reference must be added to the target too.
- The phone never writes to the App Group. Phone edits reach the complication once the watch app has received them.

## Logging

`Shared/Logic/Log.swift` wraps `os.Logger` in channels: `sync`, `storage`, `sharing`, `notifications`, `presence` and `widget`, with the bundle ID as subsystem. Use `Log.<channel>.debug(...)` for tracing (not persisted) and `.error(...)` for failures. Messages are plain `String`s and logged as public. Tests still use `print`, because the render and film harnesses report their output paths that way.

# CLAUDE.md

Rules for AI agents (and humans) working on NSSB. Read `README.md` for what the app is, `DEVELOPMENT.md` for building, testing and the test harnesses, `docs/ARCHITECTURE.md` for how data and sync work, and `docs/KNOWN_ISSUES.md` for what's open.

## Facts

- SwiftUI, iOS 17+ / watchOS 10+, Swift 5. Firebase via SPM in the iOS target only.
- Targets: `NSSB` (iOS), `NSSB WatchKit App` (sources in `NSSB WatchKit Extension/`), `NSSBComplications` (WidgetKit, embedded in the watch app) and `NSSBTests` (hosted in the iOS app).
- Shared schemes: `NSSB` (its test action runs `NSSBTests`) and `NSSB WatchKit App`.

## Rules

- **No Xcode on Linux; CI has it.** In a cloud session, push to the PR branch and read `.github/workflows/build.yml`'s result before calling a change done. CI doesn't replace a device test of sync, notifications, the complication or UI. Say so in PRs.
- **No new warnings.** The project is meant to build without warnings of its own (`DEVELOPMENT.md`). CI prints every `warning:` line, so compare against the base.
- **Target membership lives in `project.pbxproj`.** A new file needs a file reference, a group entry, and a build file in every Sources phase that should compile it. Prefer adding code to existing files when you can't open Xcode. Tests go in an existing `NSSBTests/*.swift` file.
- **A new target needs a shared scheme** in `NSSB.xcodeproj/xcshareddata/xcschemes/`, because `xcodebuild` stops auto-creating schemes once any scheme is shared.
- **Wire formats are user data.** `NonSmokingData` and `CigDesign` decode field by field; a new field goes into `CodingKeys` and `init(from:)`. Never rename or retype keys: saved files, watch payloads, share links (`https://nssb.lmunck.com/import/?d0=…`) and Firestore documents in the wild must keep decoding.
- **`lastUpdate` means when it changed, not when it was sent.** Leave stamping to `NonSmokingData.touch(ifChangedFrom:)` in the stores' `didSet`. Don't set it at send time.
- **Phone and watch stores are parallel.** A sync fix in `WCSessionPhone` almost always belongs in `WCSessionWatch` too.
- **The complication compiles a subset of `/Shared`** (see `docs/ARCHITECTURE.md`). If one of those files starts referencing something new, add that file to `NSSBComplications` too, or the extension stops building.
- **Logging:** `Log.<channel>.debug/error` (`Shared/Logic/Log.swift`), not `print`, in app code. Tests may print.
- **Firestore:** never conclude a write worked because the app looked happy. Read back from the server (`DEVELOPMENT.md`). The live checks run only with `TEST_RUNNER_NSSB_LIVE=1`, and CI never sets it.
- **Don't skip or loosen a test to get green.** See `docs/KNOWN_ISSUES.md` #1 for the one test that currently fails on CI.

## Where things are

| Need to change… | Look at |
|---|---|
| Break length, break stats | `Shared/Extensions/ExtDate.swift` |
| Start/stop/complete a break, the cigarette | `Shared/CigaretteViews/CigaretteView.swift` |
| Merge rules, stamping | `Shared/Models/NonSmokingData.swift` |
| Sending/receiving | `NSSB/Logic/WCSessionPhone.swift`, `NSSB WatchKit Extension/Logic/WCSessionWatch.swift` |
| Save/load, legacy migration | `Shared/Logic/CodingFunctions.swift` |
| Courtyard | `NSSB/Logic/Presence/`, `NSSB/Views/Courtyard*.swift`, `firebase/` |
| Reminders | `NSSB/Logic/ReminderRepository.swift`, `NSSB/Views/SettingsSubviews/ReminderView.swift` |
| Names | `Shared/Logic/CigNamer.swift` |
| Watch complication | `NSSBComplications/NSSBComplications.swift`, `Shared/Logic/SharedContainer.swift` |
| Logging channels | `Shared/Logic/Log.swift` |

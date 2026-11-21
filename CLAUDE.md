# CLAUDE.md

Rules for AI agents (and humans) working on NSSB. Read `README.md` for what the app is, `DEVELOPMENT.md` for building, testing and the test harnesses, `docs/ARCHITECTURE.md` for how data and sync work, and `docs/KNOWN_ISSUES.md` for what's open.

## Facts

- SwiftUI, iOS 17+ / watchOS 10+, Swift 5. Firebase via SPM in the iOS target only.
- Targets: `NSSB` (iOS), `NSSB WatchKit App` (sources in `NSSB WatchKit Extension/`), `NSSBComplications` (WidgetKit, embedded in the watch app) and `NSSBTests` (hosted in the iOS app).
- Shared schemes: `NSSB` (its test action runs `NSSBTests`) and `NSSB WatchKit App`.

## Branching and sessions

Several sessions may be open on this repo at once, and in November 2026 two of them spent a week on separate lines: features committed straight to `main`, infrastructure on a long-lived PR branch. `main` went that entire week with no CI, no `CLAUDE.md` and no `docs/`, because all of it sat on the unmerged branch, which then had to be rebuilt from scratch to land. These rules are what came out of that.

- **One task, one short-lived branch, one PR.** CI reports on pull requests and on pushes to `main`, so a PR is the only place you see a result *before* it is on `main`. Don't commit straight to `main` when another session might be working.
- **Merge within the day.** A branch outliving its task collects conflicts with `main`, and someone eventually rebuilds it rather than merging it.
- **A finished PR is never left as a draft.** One sat in draft for a week with green CI because nothing said to mark it ready. Take it out of draft the moment the work is done.
- **One session owns a branch.** If you don't own it, don't rebase it, force-push it, close its PR, or "fix" it. Say what looks wrong and leave it alone.
- **A conflicted PR is merged forward from `main`, never rebuilt.** Rebuilding throws away the review history and the reasoning in the commits, and from the outside it is indistinguishable from someone's work being discarded.
- **Delete the branch after a rebase merge.** The original commits stop being ancestors of `main`, so `git rev-list main..<branch>` reports them as unmerged and the next session reasonably concludes work went missing. Compare trees, not commits: `git diff <branch> main` empty means it all landed.
- **Look before you start.** `git log --oneline -5`, `git status` and `gh pr list` take a second and show whether someone else is already in the files you were about to change.

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
- **Don't skip or loosen a test to get green.** A test that passes locally and fails on CI is usually telling you something true about timing. The film test failed about half of all CI runs until `VisitorCigaretteView.pace` let it stretch the journey it photographs, rather than its thresholds being lowered to match the runner (`DEVELOPMENT.md` → "A journey has to outlast the camera").

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

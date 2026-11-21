# NSSB – Non-Smoking Smoke Breaks

An iPhone + Apple Watch app for taking a 5-minute "smoke break" **without the cigarette**. Tap the cigarette to light it and watch it burn down. The app counts your breaks and the money you didn't spend. On the phone, the **courtyard** shows who else is out on a break right now: you can ask for a light, give one, or wait for company, all anonymously.

- **Platforms:** iOS 17+ and watchOS 10+ (independent watch app with WidgetKit complications)
- **UI:** SwiftUI. **Dependencies:** Firebase (Auth, Core, Firestore) via SPM, iOS target only
- **Version:** 1.3 (iOS, watch and complication)
- **Bundle IDs:** `com.lmunck.NSSB`, `com.lmunck.NSSB.watchkitapp`, `com.lmunck.NSSB.watchkitapp.complications`
- **App Group:** `group.com.lmunck.NSSB` (watch app ⇄ complication)

## Features

| Feature | iPhone | Watch |
|---|---|---|
| Tap the cigarette to start/cancel a 5-minute break | ✅ | ✅ |
| Notification when the break ends | ✅ | ✅ |
| Breaks today / average / total, and money saved | ✅ | ✅ |
| Random daily reminders | ✅ | – |
| Cigarette designer, names from a curated pool, share links | ✅ | randomise + share |
| Courtyard: anonymous presence, "got a light?", waiting for company | ✅ | haptic when you're lit |
| Phone ⇄ watch sync (live messages + background application context) | ✅ | ✅ |
| Watch face complication: today's breaks / live break countdown | – | ✅ |

## Building

See **[`DEVELOPMENT.md`](DEVELOPMENT.md)** for build and test commands, simulator pairing, the render/film test harnesses and the live Firestore checks. See **[`firebase/README.md`](firebase/README.md)** for the backend. Without Firebase configured, the app runs on `SimulatedPresenceService`.

Signing uses team `3JMZLMZVTS`. The watch app and `NSSBComplications` need the **App Groups** capability with `group.com.lmunck.NSSB`. It's already in their entitlements files, and automatic signing registers it on the first device build.

**CI:** `.github/workflows/build.yml` builds both apps for the simulator (unsigned), checks that the complication is embedded, and runs `NSSBTests` on every PR and every push to `main`.

## Repository layout

```
NSSB/                        iOS app
  NSSBApp.swift, ContentView.swift
  Logic/WCSessionPhone.swift  Phone state store + watch sync
  Logic/ReminderRepository.swift
  Logic/Presence/             Courtyard: PresenceService protocol, Firestore + simulated
                              implementations, PresenceRepository, asks and waits
  Views/                      Courtyard, ask/wait, companion, settings, info, share
  Support/                    iOS-only helpers (pager drag, keyboard, fonts)
NSSB WatchKit Extension/     watchOS app sources ("NSSB WatchKit App" target)
  Logic/WCSessionWatch.swift  Watch state store + phone sync
NSSBComplications/           WidgetKit extension: watch face complications
Shared/                      Compiled into both apps (a subset also into the complication)
  Models/                    NonSmokingData (saved state), CigDesign, CodableColor, legacy v1
  Logic/                     CodingFunctions (persistence), SharedContainer (App Group),
                             Log (os.Logger), CigNamer, Colors
  CigaretteViews/, UI/, Extensions/
NSSBTests/                   XCTest, hosted in the iOS app
firebase/                    Firestore rules, indexes, setup
docs/                        Architecture notes and known issues
```

## Further reading

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): data model, persistence, sync, complication, logging
- [`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md): open issues and what needs a device test
- [`CLAUDE.md`](CLAUDE.md): rules for AI agents and contributors working in this repo

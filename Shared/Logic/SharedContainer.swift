//
//  SharedContainer.swift
//  NSSB
//
//  Hands data from the watch app to the complication (WidgetKit extension) through the
//  App Group container. Compiled into the watch app and the NSSBComplications extension.
//  Requires the App Groups capability with `appGroup` on both targets.
//

import Foundation
import WidgetKit

enum SharedContainer {
    
    static let appGroup = "group.com.lmunck.NSSB"
    private static let key = "complicationData"
    
    private static var complained = false

    /// The shared container, or nil when this process has not been granted
    /// the App Group.
    ///
    /// There used to be a `?? .standard` here, and it made a missing App
    /// Group look exactly like a working one: the watch wrote to its own
    /// container, the complication read its own, each call succeeded, and
    /// the complication simply showed nothing with nothing in the log to
    /// say why. A container that cannot carry data between two processes is
    /// worse than no container at all, so this says so and gives up.
    ///
    /// If this fires, the App Groups capability is missing from the target
    /// or from the provisioning profile it was signed with - not from the
    /// code. `DEVELOPMENT.md` and `docs/KNOWN_ISSUES.md` both cover it.
    private static var defaults: UserDefaults? {
        guard let shared = UserDefaults(suiteName: appGroup) else {
            if !complained {
                complained = true
                Log.widget.error("App Group \(appGroup) is not available to this process - the complication cannot be fed. Check the App Groups capability on this target and in its provisioning profile.")
            }
            return nil
        }
        return shared
    }
    
    /// What the complication needs: the running break, recent breaks and the price.
    /// Older breaks are dropped to keep the payload small (the complication only shows "today").
    private static func snapshot(of data: NonSmokingData) -> NonSmokingData {
        let cutoff = Date.now.addingTimeInterval(-2 * 86_400)
        return NonSmokingData(
            breaks: data.breaks.filter { $0 > cutoff },
            breakStarted: data.breakStarted,
            costPer20: data.costPer20,
            lastUpdate: .distantPast
        )
    }
    
    private static func encode(_ data: NonSmokingData) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(data)
    }
    
    /// Called by the watch app whenever its data changes. Only reloads complications
    /// when something they show actually changed (reloads are budgeted by the system).
    static func write(_ data: NonSmokingData) {
        guard let encoded = encode(snapshot(of: data)) else {
            Log.widget.error("SharedContainer.write() - encode FAIL")
            return
        }
        // No shared container, no point reloading anything: `defaults` has
        // already said why, and reloading would show the same stale entry.
        guard let defaults = defaults else { return }
        guard encoded != defaults.data(forKey: key) else { return }
        defaults.set(encoded, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
        Log.widget.debug("SharedContainer.write() - complications reloaded")
    }
    
    /// Called by the complication.
    static func read() -> NonSmokingData? {
        guard let defaults = defaults,
              let stored = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(NonSmokingData.self, from: stored)
    }
}

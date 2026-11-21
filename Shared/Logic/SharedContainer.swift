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
    
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
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
        guard encoded != defaults.data(forKey: key) else { return }
        defaults.set(encoded, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
        Log.widget.debug("SharedContainer.write() - complications reloaded")
    }
    
    /// Called by the complication.
    static func read() -> NonSmokingData? {
        guard let stored = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(NonSmokingData.self, from: stored)
    }
}

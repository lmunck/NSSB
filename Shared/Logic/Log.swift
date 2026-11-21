//
//  Log.swift
//  NSSB
//
//  Unified logging through os.Logger. View in Console.app or Xcode's console and
//  filter by subsystem (the bundle id) and category.
//
//  Log.<category>.debug(...) is for tracing - it isn't persisted, so it costs
//  nothing on a user's device. Log.<category>.error(...) is for failures.
//
//  Messages are plain Strings rather than OSLogMessage on purpose: OSLogMessage
//  interpolations are escaping autoclosures, which would demand an explicit
//  `self.` on every property mentioned in a log line inside a class. Everything
//  is logged as public; nothing logged here is personal.
//

import Foundation
import os

struct LogChannel {
    fileprivate let logger: Logger
    
    init(_ category: String) {
        logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.lmunck.NSSB", category: category)
    }
    
    func debug(_ message: String) { logger.debug("\(message, privacy: .public)") }
    func error(_ message: String) { logger.error("\(message, privacy: .public)") }
}

enum Log {
    /// Phone ⇄ watch sync and merging
    static let sync = LogChannel("sync")
    /// Saving and loading the data file
    static let storage = LogChannel("storage")
    /// Share links and cigarette design encoding
    static let sharing = LogChannel("sharing")
    /// Local notifications and reminders
    static let notifications = LogChannel("notifications")
    /// The courtyard: presence, asking for a light, waiting for company
    static let presence = LogChannel("presence")
    /// Watch face complication timelines
    static let widget = LogChannel("widget")
}

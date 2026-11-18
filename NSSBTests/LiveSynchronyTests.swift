//
//  LiveSynchronyTests.swift
//  NSSBTests
//

// The one thing SimulatedPresenceService cannot tell you: whether any of this
// works against the real backend.
//
// Everything else in this target runs on the stand-in, which is fast, offline
// and deterministic - and which has never once rejected a write. The live
// backend has, silently, twice: `setData(from:)` reports encoding failures
// and nothing else, so a document the rules refused still looks like a
// success, still comes back from the local cache, and still fills the first
// snapshot. Both devices showed each other a courtyard the server knew
// nothing about.
//
// So this file drives the real service against the real project, with the
// other person played by a second anonymous client over the REST API, and
// checks the server rather than the screen. It is skipped unless it is asked
// for by name, because it needs the network and writes real documents:
//
//   TEST_RUNNER_NSSB_LIVE=1 xcodebuild test -project NSSB.xcodeproj \
//     -scheme NSSB -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
//     -only-testing:NSSBTests/LiveSynchronyTests
//
// The TEST_RUNNER_ prefix is not decoration: xcodebuild does not hand its own
// environment to the test process, it forwards that prefix and strips it. A
// plain NSSB_LIVE=1 silently skips all three and still reports success.
//
// It cleans up after itself, and the rules let anybody clear a wait five
// minutes after it expired if it ever does not.

import XCTest
@testable import NSSB

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@MainActor
final class LiveSynchronyTests: XCTestCase {
    
    private var repository: PresenceRepository!
    private var stranger: Stranger!
    
    override func setUp() async throws {
        
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["NSSB_LIVE"] == "1",
            "live test - set NSSB_LIVE=1 to run it"
        )
        
        #if canImport(FirebaseCore)
        let options = try XCTUnwrap(FirebaseApp.app()?.options, "Firebase is not configured")
        stranger = Stranger(apiKey: options.apiKey ?? "", projectId: options.projectID ?? "")
        try await stranger.signIn()
        #else
        throw XCTSkip("the Firebase SDK is not linked")
        #endif
        
        UserDefaults.standard.removeObject(forKey: "presence.liveBreakId")
        UserDefaults.standard.removeObject(forKey: "presence.liveBreakStart")
        
        #if canImport(FirebaseFirestore)
        repository = PresenceRepository(service: FirestorePresenceService())
        #else
        throw XCTSkip("the Firestore SDK is not linked")
        #endif
        
        await repository.start()
        XCTAssertNotNil(repository.uid, "anonymous sign-in failed")
    }
    
    override func tearDown() async throws {
        repository = nil
        stranger = nil
    }
    
    /// Being joined: the write really landed, the listener really fired, and
    /// the instant the stranger wrote is the instant this device will light
    /// its cigarette at.
    func testSomebodyJoinsYouForReal() async throws {
        
        await repository.waitForCompany(design: design())
        let mine = try XCTUnwrap(repository.company.openWait, "nothing was published")
        
        // On the server, not in the cache. This is the check that was missing
        // the day two devices showed each other an empty collection.
        let onServer = try await stranger.read(wait: mine.id)
        XCTAssertEqual(onServer["name"] as? String, "Charcoal Gull")
        XCTAssertEqual(onServer["paired"] as? Bool, false)
        
        let litAt = Date.now
        try await stranger.join(wait: mine.id, as: "Paper Kestrel", at: litAt)
        
        try await until("the pairing to arrive over the listener") {
            self.repository.company.companions.first != nil
        }
        
        XCTAssertEqual(repository.company.companions.first?.name, "Paper Kestrel")
        XCTAssertEqual(repository.company.companions.first?.country, "JP")
        
        let shared = try XCTUnwrap(repository.company.litAt)
        XCTAssertEqual(shared.timeIntervalSince1970, litAt.timeIntervalSince1970, accuracy: 1,
                       "both cigarettes have to burn from the instant that was written")
        
        try await until("the wait to be cleared from the server") {
            await self.stranger.exists(wait: mine.id) == false
        }
    }
    
    /// Taking somebody's chair: the update really landed where they can read
    /// it, which is the only way they ever learn when to light up.
    func testTakingAChairForReal() async throws {
        
        let theirs = try await stranger.wait(named: "Hollow Lantern")
        
        await repository.waitWith(theirs, design: design())
        
        XCTAssertEqual(repository.company.companions.first?.name, "Hollow Lantern")
        let litAt = try XCTUnwrap(repository.company.litAt)
        
        let onServer = try await stranger.read(wait: theirs.id)
        XCTAssertEqual(onServer["paired"] as? Bool, true)
        XCTAssertEqual(onServer["partnerName"] as? String, "Charcoal Gull")
        
        let written = try XCTUnwrap(onServer["litAt"] as? Date)
        XCTAssertEqual(written.timeIntervalSince1970, litAt.timeIntervalSince1970, accuracy: 1)
        
        try await stranger.delete(wait: theirs.id)
    }
    
    /// Nobody comes. The thirty seconds really elapse and the document really
    /// goes, which is the only thing keeping the collection bounded.
    func testAnUnansweredWaitClearsItselfForReal() async throws {
        
        BreakWait.window = 2
        defer { BreakWait.window = 30 }
        
        await repository.waitForCompany(design: design())
        let mine = try XCTUnwrap(repository.company.openWait)
        
        try await until("the wait to run out", timeout: 20) {
            self.repository.company == .alone
        }
        
        try await until("the document to be cleared from the server", timeout: 20) {
            await self.stranger.exists(wait: mine.id) == false
        }
    }
    
    // MARK: Helpers
    
    private func design(title: String = "Charcoal Gull") -> CigDesign {
        var design = CigDesign()
        design.title = title
        return design
    }
    
    private func until(
        _ what: String,
        timeout: TimeInterval = 15,
        _ condition: () async -> Bool
    ) async throws {
        
        let deadline = Date.now.addingTimeInterval(timeout)
        
        while Date.now < deadline {
            if await condition() { return }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        
        XCTFail("timed out waiting for \(what)")
    }
}

/// The other person, over the REST API.
///
/// A second anonymous client, because there is only one Firebase Auth session
/// per process and a shared break needs two of them. Everything it does is
/// something a real second device would do, and the rules judge it exactly
/// the same way.
private actor Stranger {
    
    private let apiKey: String
    private let projectId: String
    private var uid = ""
    private var token = ""
    
    private var base: String {
        "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents"
    }
    
    init(apiKey: String, projectId: String) {
        self.apiKey = apiKey
        self.projectId = projectId
    }
    
    func signIn() async throws {
        let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(apiKey)")!
        let body = try await send("POST", url, ["returnSecureToken": true], authed: false)
        uid = body["localId"] as? String ?? ""
        token = body["idToken"] as? String ?? ""
        guard token.isEmpty == false else { throw LiveError.notSignedIn }
    }
    
    /// A wait of their own, for this device to come and join.
    func wait(named name: String) async throws -> BreakWait {
        
        let id = "live-" + UUID().uuidString.prefix(8)
        let created = Date.now
        var design = CigDesign()
        design.title = name
        
        let fields: [String: Any] = [
            "id": ["stringValue": id],
            "waiterHash": ["stringValue": BreakOwner.hash(uid: uid, breakId: id)],
            "createdAt": ["timestampValue": Self.stamp(created)],
            "expiresAt": ["timestampValue": Self.stamp(created.addingTimeInterval(30))],
            "name": ["stringValue": name],
            "country": ["stringValue": "PT"],
            "tzOffset": ["integerValue": "3600"],
            "paired": ["booleanValue": false],
        ]
        
        _ = try await send("POST", URL(string: "\(base)/waits?documentId=\(id)")!, ["fields": fields])
        
        return BreakWait(
            id: id,
            waiterHash: BreakOwner.hash(uid: uid, breakId: id),
            createdAt: created,
            expiresAt: created.addingTimeInterval(30),
            name: name,
            country: "PT",
            tzOffset: 3600,
            design: design,
            paired: false,
            partnerName: nil,
            partnerDesign: nil,
            partnerCountry: nil,
            partnerTzOffset: nil,
            litAt: nil
        )
    }
    
    func join(wait id: String, as name: String, at litAt: Date) async throws {
        
        let mask = ["paired", "partnerName", "partnerCountry", "partnerTzOffset", "litAt"]
            .map { "updateMask.fieldPaths=\($0)" }
            .joined(separator: "&")
        
        let fields: [String: Any] = [
            "paired": ["booleanValue": true],
            "partnerName": ["stringValue": name],
            "partnerCountry": ["stringValue": "JP"],
            "partnerTzOffset": ["integerValue": "32400"],
            "litAt": ["timestampValue": Self.stamp(litAt)],
        ]
        
        _ = try await send("PATCH", URL(string: "\(base)/waits/\(id)?\(mask)")!, ["fields": fields])
    }
    
    func read(wait id: String) async throws -> [String: Any] {
        
        let body = try await send("GET", URL(string: "\(base)/waits/\(id)")!, nil)
        let fields = body["fields"] as? [String: Any] ?? [:]
        
        var plain: [String: Any] = [:]
        for (key, value) in fields {
            guard let value = value as? [String: Any] else { continue }
            if let string = value["stringValue"] as? String { plain[key] = string }
            if let flag = value["booleanValue"] as? Bool { plain[key] = flag }
            if let stamp = value["timestampValue"] as? String {
                plain[key] = ISO8601DateFormatter.live.date(from: stamp)
            }
        }
        return plain
    }
    
    func exists(wait id: String) async -> Bool {
        (try? await send("GET", URL(string: "\(base)/waits/\(id)")!, nil)) != nil
    }
    
    func delete(wait id: String) async throws {
        _ = try? await send("DELETE", URL(string: "\(base)/waits/\(id)")!, nil)
    }
    
    @discardableResult
    private func send(
        _ method: String,
        _ url: URL,
        _ body: [String: Any]?,
        authed: Bool = true
    ) async throws -> [String: Any] {
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authed {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw LiveError.refused(code) }
        
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
    
    private static func stamp(_ date: Date) -> String {
        ISO8601DateFormatter.live.string(from: date)
    }
}

private enum LiveError: Error {
    case notSignedIn
    case refused(Int)
}

private extension ISO8601DateFormatter {
    static let live: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

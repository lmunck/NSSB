//
//  BreakPresence.swift
//  NSSB
//

// One live smoke break, as everyone else in the courtyard sees it.
//
// Deliberately small. No city, no distance, no break stats, no way to reach
// the person afterwards - and the document is deleted when the cigarette goes
// out, so there is no record anywhere of who stood next to whom.

import Foundation
import CryptoKit

enum BreakOwner {
    
    /// Must match `hashing.sha256(request.auth.uid + breakId).toHexString().lower()`
    /// in firestore.rules exactly, or every write is denied.
    ///
    /// Hex rather than base64 deliberately. Base64 has two ways to disagree -
    /// padding, and the URL-safe alphabet - and when the two sides disagree
    /// the only symptom is a permission error from a rule that looks correct.
    /// Hex has one representation and a case convention.
    static func hash(uid: String, breakId: String) -> String {
        let digest = SHA256.hash(data: Data((uid + breakId).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// What anybody in the courtyard is ever told about somebody else: a rolled
/// name, a region code they may have withheld, and an offset from GMT. Never a
/// city, never a distance, never GPS.
///
/// Shared by a live break and an ask for a light, because both stand in the
/// same courtyard and are told the same way.
protocol CourtyardStranger {
    var name: String { get }
    var country: String? { get }
    var tzOffset: Int { get }
}

extension CourtyardStranger {
    
    /// "06:41" where they are. The cheapest detail in the whole feature and
    /// the one that does the most work.
    func localTimeString(at now: Date = .now) -> String {
        
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: tzOffset) ?? .gmt
        
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}

struct BreakPresence: Codable, Equatable, Identifiable, CourtyardStranger {
    
    /// Identifies the break, never the person. A new one every time, so two
    /// breaks by the same user cannot be linked together by anyone reading.
    let id: String
    
    /// Proof of ownership that is useless to everyone else.
    ///
    /// This used to be the raw anonymous uid, which the security rules need
    /// but which any signed-in client could also read - and since every break
    /// by one person carried the same uid, their breaks were linkable by
    /// anyone reading the collection. Firestore rules are per-document and
    /// cannot hide a field, so the only way to keep a uid private is not to
    /// store one.
    ///
    /// sha256(uid + breakId) still lets the rules verify ownership, because
    /// they can recompute it from request.auth.uid. But it is different for
    /// every break, so it links nothing.
    let ownerHash: String
    
    let startedAt: Date
    
    /// startedAt + Date.breakLength.
    ///
    /// Every reader filters on this, so a break disappears from the courtyard
    /// at the right moment whether or not its document has been deleted yet.
    /// It is also the field a Firestore TTL policy would watch, if one is ever
    /// added - that needs the Blaze plan, so for now the app deletes its own
    /// documents instead. See firebase/README.md.
    let endsAt: Date
    
    /// "Charcoal Gull" - rolled from the vocabulary, never typed by anyone.
    let name: String
    
    /// Region code from the device locale. Never GPS, and optional, because
    /// there are places where showing a flag is not a neutral act.
    let country: String?
    
    /// Seconds from GMT, so the courtyard can say "06:41 there" without ever
    /// knowing where "there" is.
    let tzOffset: Int
    
    let design: CigDesign
}

extension BreakPresence {
    
    /// Builds the document for a break that has just started. `startedAt` is
    /// passed in rather than taken as "now" so that a break which was already
    /// running when the app relaunched is republished at its true position in
    /// the burn, not restarted.
    /// `id` is passed in when republishing a break that is already running,
    /// so the same document is overwritten rather than a second one created.
    static func starting(
        at startedAt: Date,
        id: String = UUID().uuidString,
        uid: String,
        design: CigDesign,
        shareCountry: Bool = true
    ) -> BreakPresence {
        
        BreakPresence(
            id: id,
            ownerHash: BreakOwner.hash(uid: uid, breakId: id),
            startedAt: startedAt,
            endsAt: startedAt.addingTimeInterval(Date.breakLength),
            name: design.title,
            country: shareCountry ? Locale.current.region?.identifier : nil,
            tzOffset: TimeZone.current.secondsFromGMT(for: startedAt),
            design: design
        )
    }
    
    /// 0 = just lit, 1 = gone out. The courtyard renders each cigarette at
    /// its own true burn position, which is also how you tell at a glance
    /// whether someone is good for a light or good for company.
    func progress(at now: Date = .now) -> Double {
        let total = endsAt.timeIntervalSince(startedAt)
        guard total > 0 else { return 1 }
        return min(max(now.timeIntervalSince(startedAt) / total, 0), 1)
    }
    
    func isLive(at now: Date = .now) -> Bool {
        now < endsAt
    }
    
}

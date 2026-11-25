//
//  BreakCompany.swift
//  NSSB
//

// A shared break, as the wrist is told about it.
//
// The courtyard stays on the phone, for the reason it always has: there is no
// room on a watch for a room full of people, and a glance at your wrist is
// not the moment for one. But somebody actually standing with you is not a
// room full of people - it is one or two cigarettes burning beside your own,
// and a watch has room for that.
//
// So this is the whole of what crosses: who is here, what their cigarette
// looks like, when it was lit, and which side of you they are on. No country,
// no offset, no hash, no document the break outlives. The watch cannot ask
// anybody for a light and cannot stand anybody out in a courtyard, so it is
// not told anything it would need for either.
//
// Not part of NonSmokingData and never saved. Company lasts exactly as long
// as the cigarettes do and nothing about it is kept, which is the first
// principle of the whole layer - putting it in the file that gets written to
// disk and merged by `lastUpdate` would break that twice over. It also has no
// stamp of its own: there is nothing to order, because only the phone ever
// writes one of these.

import Foundation

struct BreakCompany: Codable, Equatable {

    /// At most two, because there are two sides of you to stand on.
    var beside: [Companion] = []

    /// Somebody standing with you, trimmed to what can be drawn.
    struct Companion: Codable, Equatable, Identifiable {

        /// The document that brought them here - the wait they took a chair
        /// in, or the ask they answered - and not their name, because two
        /// people can be called the same thing. The phone keys its views on
        /// this, so the watch does too.
        var id: String = ""

        /// "Charcoal Gull". Rolled from the vocabulary, never typed.
        var name: String = ""

        /// Their cigarette, so what stands beside yours is theirs rather
        /// than a second copy of your own.
        var design: CigDesign = CigDesign()

        /// When *their* cigarette was lit, which is not always when yours
        /// was. Two people who lit together share this instant exactly;
        /// somebody who came over to light you was already burning, so
        /// theirs goes out before yours does.
        ///
        /// It is also what makes a late payload harmless. A companion is
        /// drawn for as long as their own cigarette lasts and not a second
        /// longer, so an application context the watch only picks up an hour
        /// later shows nobody - rather than somebody who left an hour ago.
        var startedAt: Date = .distantPast

        /// Which side of you they are on, so the wrist and the phone agree
        /// about where somebody is standing.
        var onLeft: Bool = false
    }
}

// The watch payload, decoded field by field the way CigDesign and
// NonSmokingData are: a field that is missing or unreadable falls back to its
// default rather than failing the whole message, so a phone and a watch on
// different builds still understand each other. When adding a field, add it
// to CodingKeys and here.
extension BreakCompany {

    enum CodingKeys: String, CodingKey {
        case beside
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let arriving: [Companion]? = (try? container.decodeIfPresent([Companion].self, forKey: .beside)) ?? nil

        // Somebody with no id is not somebody: nothing can be keyed on them
        // and nothing can be drawn for them.
        self.beside = (arriving ?? []).filter { $0.id.isEmpty == false }
    }
}

extension BreakCompany.Companion {

    enum CodingKeys: String, CodingKey {
        case id, name, design, startedAt, onLeft
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func field<T: Decodable>(_ type: T.Type, _ key: CodingKeys) -> T? {
            (try? container.decodeIfPresent(type, forKey: key)) ?? nil
        }
        self.id = field(String.self, .id) ?? ""
        self.name = field(String.self, .name) ?? ""
        self.design = field(CigDesign.self, .design) ?? CigDesign()

        // No ignition instant means a cigarette that was never lit, and an
        // unlit companion is one who is already out of the frame: distantPast
        // fails `isLive` rather than drawing somebody at an unknown position.
        self.startedAt = field(Date.self, .startedAt) ?? .distantPast
        self.onLeft = field(Bool.self, .onLeft) ?? false
    }
}

// MARK: - Their own clock

extension BreakCompany.Companion {

    /// How far down their cigarette is, 0 to 1. Theirs, not yours.
    func progress(at now: Date = .now) -> Double {
        min(max(now.timeIntervalSince(startedAt) / Date.breakLength, 0), 1)
    }

    /// True while there is still a cigarette to draw.
    ///
    /// Every reader filters on this, exactly as the courtyard filters on
    /// `BreakPresence.endsAt`: a companion leaves at the right moment
    /// whether or not a fresh payload has arrived to say so.
    func isLive(at now: Date = .now) -> Bool {
        progress(at: now) < 1
    }
}

// MARK: - The wire

extension BreakCompany {

    /// Nobody. The empty payload, which is also what a phone with no
    /// courtyard connection and a watch that has heard nothing both hold.
    static let nobody = BreakCompany()

    var isEmpty: Bool { beside.isEmpty }

    /// Whoever is still burning, at their own position.
    func standing(at now: Date = .now) -> [Companion] {
        beside.filter { $0.isLive(at: now) }
    }

    /// Encoded for WatchConnectivity. Its own JSON rather than a key inside
    /// the data payload, because this is not data: it is not saved, not
    /// merged and not stamped, and the one thing it must never do is take
    /// part in the merge that decides whether a break is running.
    func payload() -> Data? {
        do {
            return try JSONEncoder().encode(self)
        } catch {
            Log.sync.error("BreakCompany - could not encode company: \(error.localizedDescription)")
            return nil
        }
    }

    init?(payload: Data) {
        do {
            self = try JSONDecoder().decode(BreakCompany.self, from: payload)
        } catch {
            Log.sync.error("BreakCompany - could not decode company: \(error.localizedDescription)")
            return nil
        }
    }
}

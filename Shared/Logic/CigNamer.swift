//
//  CigNamer.swift
//  NSSB
//
//  Created by Anders Munck on 10/07/2024.
//

// Generates a random cigarette design, and the name that goes with it.
//
// The vocabulary below is deliberately small and hand-picked: 280 adjectives
// and 549 nouns, which is 153,720 names. It replaced a 1323x6799
// general-purpose English word list that produced 899,507,700 combinations,
// most of which did not read like a name ("SphericalMonasticism80",
// "WarpedViability23") and some of which should never have been shown to
// anyone. This pool is meant to become the only source of names, so every
// word in it has to be one a user would be happy to be called in front of
// a stranger.
//
// Keep that bar when editing: concrete nouns, no abstractions, no acronyms,
// no hyphens, nothing medical, nothing to do with illness or dying.

import SwiftUI

func getRandom() -> CigDesign {
    
    let random = CigDesign(
        title: randomCigaretteName(),
        widthPercentage: CGFloat.random(in: CigDesign.widthRange),
        filterPercentage: Double.random(in: CigDesign.filterRange),
        filter: Color(hue: Double.random(in: (0...1)), saturation: 0.6, brightness: Bool.random() ? 0.35 : 1),
        body: Color(hue: Double.random(in: (0...1)), saturation: 0.4, brightness: Bool.random() ? 1 : 0.5),
        ash: Color(hue: 0, saturation: 0, brightness: 0.3),
        glow: Color(hue: Double.random(in: (0...1)), saturation: 1, brightness: 1),
        background: Color(hue: Double.random(in: (0...1)), saturation: 1, brightness: 1)
    )
    
    return random
}

// MARK: Naming

/// "Hollow Lantern". Two words, a space, no trailing digits.
func randomCigaretteName() -> String {
    
    let adjective = randomCigaretteAdjective()
    var noun = randomCigaretteNoun()
    
    // A handful of words sit in both lists, so "Amber Amber" is possible.
    // Vanishingly unlikely, but it reads like a bug, so re-roll it.
    while noun == adjective {
        noun = randomCigaretteNoun()
    }
    
    return "\(adjective.capitalized) \(noun.capitalized)"
}

/// Exposed separately so each half of the name can be re-rolled on its own.
func randomCigaretteAdjective() -> String {
    cigaretteAdjectives.randomElement() ?? "Hollow"
}

func randomCigaretteNoun() -> String {
    cigaretteNouns.randomElement() ?? "Lantern"
}

// MARK: Reading a name back

private let cigaretteAdjectiveSet = Set(cigaretteAdjectives)
private let cigaretteNounSet = Set(cigaretteNouns)

/// Splits "Reckless Sunset" into its two halves, or nil when the title did not
/// come from the vocabulary - either an empty name, or one typed back when the
/// app still had a text field.
func cigNameParts(_ title: String) -> (adjective: String, noun: String)? {
    
    let words = title.split(separator: " ")
    guard words.count == 2 else { return nil }
    
    let adjective = String(words[0])
    let noun = String(words[1])
    
    guard cigaretteAdjectiveSet.contains(adjective.lowercased()),
          cigaretteNounSet.contains(noun.lowercased())
    else { return nil }
    
    return (adjective, noun)
}

/// True for a name the user typed before the field was removed. An empty - or
/// whitespace-only - title is not legacy, it just means this cigarette has
/// never been named, and a strikethrough over nothing reads as a glitch.
func isLegacyCigName(_ title: String) -> Bool {
    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        && cigNameParts(title) == nil
}

/// Re-rolls the first word and keeps the second.
func rerollCigAdjective(in title: String) -> String {
    
    guard let parts = cigNameParts(title) else { return randomCigaretteName() }
    
    var adjective = randomCigaretteAdjective()
    
    // Every tap has to visibly change something, or it reads as a dead
    // control - and "Amber Amber" reads as a bug. Roll past both.
    while adjective.caseInsensitiveCompare(parts.adjective) == .orderedSame
       || adjective.caseInsensitiveCompare(parts.noun) == .orderedSame {
        adjective = randomCigaretteAdjective()
    }
    
    return "\(adjective.capitalized) \(parts.noun)"
}

/// Re-rolls the second word and keeps the first.
func rerollCigNoun(in title: String) -> String {
    
    guard let parts = cigNameParts(title) else { return randomCigaretteName() }
    
    var noun = randomCigaretteNoun()
    
    while noun.caseInsensitiveCompare(parts.noun) == .orderedSame
       || noun.caseInsensitiveCompare(parts.adjective) == .orderedSame {
        noun = randomCigaretteNoun()
    }
    
    return "\(parts.adjective) \(noun.capitalized)"
}

// MARK: Vocabulary

private let cigaretteAdjectives: [String] = [
    "amber", "ancient", "ardent", "arctic", "ashen", "autumn", "bare", "bashful",
    "battered", "bitter", "black", "bleached", "blunt", "bold", "bone", "borrowed",
    "brackish", "brass", "brave", "brief", "bright", "brittle", "broken", "bronze",
    "brooding", "burnt", "candid", "careless", "charcoal", "chilly", "civil", "clear",
    "clouded", "coarse", "cobalt", "cold", "common", "cool", "copper", "coral",
    "crimson", "crooked", "crumpled", "curious", "dappled", "daring", "dark", "deep",
    "delicate", "devout", "dim", "distant", "dogged", "drifting", "dry", "dusky",
    "dusty", "early", "earnest", "easy", "elder", "empty", "errant", "even",
    "evening", "faded", "faint", "faithful", "fallow", "feral", "fickle", "final",
    "first", "flinty", "fond", "forgotten", "formal", "fragile", "frail", "frank",
    "frayed", "fresh", "frosted", "frozen", "gallant", "gentle", "glacial", "gleaming",
    "golden", "gracious", "grand", "grave", "gritty", "guarded", "hallowed", "handsome",
    "hardy", "hazy", "heavy", "hidden", "hollow", "honest", "humble", "hushed",
    "idle", "inland", "iron", "ivory", "jade", "keen", "kindly", "languid",
    "last", "late", "lawful", "lazy", "lean", "level", "listless", "little",
    "lonely", "long", "loyal", "lucky", "luminous", "lunar", "marble", "meek",
    "mellow", "merry", "mild", "misty", "modest", "moonlit", "murky", "mute",
    "nameless", "narrow", "nimble", "noble", "nocturnal", "northern", "oaken", "obscure",
    "ochre", "oiled", "old", "olive", "opal", "ordinary", "pale", "papery",
    "patient", "pearl", "pewter", "placid", "plain", "pleasant", "polished", "poor",
    "private", "prudent", "quiet", "ragged", "rakish", "rare", "raw", "ready",
    "reckless", "reluctant", "restless", "rough", "rowdy", "rueful", "russet", "rusted",
    "sable", "saffron", "sage", "salt", "sandy", "scarlet", "seaward", "second",
    "sepia", "serene", "shaded", "shallow", "sharp", "shuttered", "silent", "silken",
    "silver", "simple", "singular", "slate", "sleepy", "slender", "slight", "slow",
    "small", "smoky", "smooth", "sober", "soft", "solemn", "sombre", "southern",
    "spare", "spent", "splendid", "square", "staid", "stark", "steady", "steep",
    "stern", "still", "stolen", "stony", "stout", "straight", "strange", "stray",
    "stubborn", "sudden", "sullen", "sunlit", "supple", "sweet", "tacit", "tame",
    "tarnished", "tawny", "teal", "temperate", "tender", "thin", "threadbare", "thrifty",
    "tidal", "timber", "tin", "tired", "tranquil", "true", "umber", "unlit",
    "unmarked", "upland", "upright", "urbane", "vacant", "vagrant", "valiant", "velvet",
    "vernal", "waiting", "wandering", "wary", "waxen", "wayward", "weary", "western",
    "whispered", "wicked", "wide", "wild", "wilful", "willing", "windswept", "winter",
    "wintry", "wistful", "worn", "woven", "wry", "yellow", "young", "zealous"
]

private let cigaretteNouns: [String] = [
    // fire and light
    "ember", "lantern", "beacon", "flare", "tinder", "spark", "candle", "torch",
    "wick", "filament", "glow", "ash", "cinder", "flint", "bonfire", "hearth",
    "forge", "furnace", "kiln", "flue", "chimney", "brazier", "taper", "tinderbox",
    "lamplight", "firelight", "sconce", "kerosene",
    // smoke
    "plume", "wisp", "curl", "coil", "drift", "vapour", "haze", "fume",
    "incense", "censer",
    // weather and sky
    "fog", "mist", "drizzle", "squall", "gale", "frost", "thaw", "dusk",
    "dawn", "twilight", "gloaming", "monsoon", "zephyr", "thunder", "aurora", "eclipse",
    "cloudbank", "downpour", "flurry", "sleet", "rime", "dewfall", "moonrise", "sunset",
    "nightfall", "daybreak", "starlight", "moonlight", "horizon", "blizzard", "snowdrift", "icicle",
    "tempest", "overcast",
    // birds
    "heron", "raven", "crow", "magpie", "starling", "swallow", "kestrel", "falcon",
    "plover", "curlew", "lapwing", "gull", "tern", "wren", "finch", "nightjar",
    "owl", "albatross", "cormorant", "lark", "linnet", "siskin", "redwing", "woodcock",
    "snipe", "bittern", "egret", "crane", "stork", "petrel", "puffin", "kittiwake",
    "goldcrest", "chaffinch", "bullfinch", "yellowhammer", "stonechat", "warbler", "pipit", "wagtail",
    "nuthatch", "jackdaw", "rook", "chough", "osprey", "nightingale",
    // animals
    "fox", "hare", "wolf", "stag", "lynx", "marten", "otter", "badger",
    "mole", "moth", "hornet", "viper", "adder", "mantis", "jackal", "bison",
    "ibex", "boar", "elk", "roebuck", "fawn", "vixen", "weasel", "stoat",
    "polecat", "dormouse", "vole", "ermine", "mink", "hedgehog", "marmot", "lemming",
    "civet", "caracal",
    // materials
    "brass", "copper", "tin", "pewter", "zinc", "nickel", "cobalt", "bronze",
    "iron", "slate", "quartz", "basalt", "granite", "obsidian", "amber", "resin",
    "lacquer", "enamel", "celluloid", "velvet", "linen", "canvas", "twine", "hemp",
    "silk", "muslin", "calico", "gauze", "felt", "tweed", "corduroy", "flannel",
    "chamois", "vellum", "parchment", "foil", "steel", "graphite", "mica", "alabaster",
    // stones and woods
    "marble", "onyx", "agate", "jasper", "opal", "garnet", "topaz", "beryl",
    "ebony", "teak", "mahogany", "walnut", "cedar", "cypress", "aspen", "birch",
    "rowan", "hawthorn", "blackthorn", "willow", "alder", "hazel", "holly", "yew",
    "pine", "larch", "spruce", "juniper", "sandalwood", "boxwood",
    // nautical
    "harbour", "quay", "jetty", "pier", "lighthouse", "anchor", "mooring", "hull",
    "keel", "mast", "rigging", "sextant", "compass", "meridian", "latitude", "tide",
    "undertow", "shoal", "estuary", "lagoon", "breakwater", "ferry", "trawler", "schooner",
    "clipper", "cutter", "sloop", "ketch", "dinghy", "skiff", "barge", "tugboat",
    "buoy", "capstan", "bowsprit", "gunwale", "halyard", "hawser", "lanyard", "fathom",
    "leeward", "windward", "starboard", "seawall", "slipway", "drydock", "boathouse", "tiller",
    "rudder", "prow", "spindrift", "brine",
    // sea edge
    "kelp", "barnacle", "driftwood", "flotsam", "surf", "swell", "seafoam", "shingle",
    "sandbar", "mudflat",
    // architecture
    "alley", "courtyard", "terrace", "balcony", "stairwell", "doorway", "threshold", "arcade",
    "colonnade", "cloister", "chapel", "belfry", "attic", "cellar", "loft", "veranda",
    "portico", "gatehouse", "boulevard", "promenade", "archway", "alcove", "landing", "corridor",
    "vestibule", "rooftop", "parapet", "buttress", "gable", "dormer", "cornice", "lintel",
    "transom", "awning", "canopy", "forecourt", "mews", "lane", "byway", "towpath",
    "footbridge", "viaduct", "aqueduct", "tunnel", "platform", "tollgate", "turnstile", "gateway",
    "stile", "milestone", "signpost", "lamppost", "bollard", "cobblestone", "flagstone", "doorstep",
    // interiors
    "windowsill", "fireplace", "mantel", "bannister", "trapdoor", "skylight", "hallway", "pantry",
    "scullery", "larder", "parlour", "snug",
    // landscape
    "moor", "heath", "fen", "marsh", "thicket", "copse", "hollow", "glade",
    "ridge", "scree", "tor", "cairn", "bluff", "delta", "oasis", "dune",
    "steppe", "tundra", "savanna", "canyon", "gorge", "ravine", "gully", "hillside",
    "foothill", "summit", "plateau", "escarpment", "crag", "outcrop", "boulder", "pebble",
    "saltmarsh", "reedbed", "meadow", "pasture", "paddock", "orchard", "vineyard", "hedgerow",
    "woodland", "grove", "coppice", "clearing", "undergrowth", "bracken", "heather", "gorse",
    "thistle", "nettle", "bramble", "lichen", "moss", "fern",
    // small flowers
    "clover", "poppy", "cowslip", "primrose", "bluebell", "celandine", "campion", "vetch",
    "yarrow", "meadowsweet",
    // time and ritual
    "vespers", "curfew", "interval", "interlude", "recess", "solstice", "equinox", "vigil",
    "nocturne", "reveille", "armistice", "intermission", "respite", "furlough", "midnight", "midday",
    "noontide", "eventide", "matins", "sundown", "evensong",
    // music
    "cadence", "refrain", "prelude", "overture", "elegy", "lullaby", "fanfare", "tremolo",
    "sonata", "rhapsody", "serenade", "madrigal", "canticle", "chorale", "descant", "octave",
    "reprise", "encore", "coda",
    // objects
    "pocketwatch", "telegram", "postcard", "almanac", "ledger", "inkwell", "tramline", "typewriter",
    "gramophone", "phonograph", "hourglass", "sundial", "barometer", "telescope", "spyglass", "kaleidoscope",
    "monocle", "spectacles", "snuffbox", "ashtray", "matchbox", "penknife", "latchkey", "coinpurse",
    "satchel", "haversack", "knapsack", "valise", "hatbox", "umbrella", "overcoat", "waistcoat",
    "necktie", "cufflink", "lapel", "collar", "fedora", "trilby", "bowler", "thimble",
    "bobbin", "spindle", "loom",
    // spice and bitters
    "bitters", "quinine", "chicory", "espresso", "cordial", "treacle", "molasses", "clove",
    "anise", "cardamom", "liquorice", "vanilla", "cinnamon", "nutmeg", "peppercorn", "tamarind",
    "bergamot", "citron", "quince", "damson", "sloe", "medlar", "mulberry", "elderflower",
    "blackcurrant", "rosehip",
    // trades and figures
    "lamplighter", "nightwatch", "sentry", "watchman", "ferryman", "bosun", "chandler", "cooper",
    "draper", "fletcher", "glazier", "thatcher",
    // atmosphere
    "echo", "murmur", "hush", "whisper", "rumour", "errand", "detour", "shortcut",
    "crossroads", "waypoint", "outskirts", "hinterland"
]

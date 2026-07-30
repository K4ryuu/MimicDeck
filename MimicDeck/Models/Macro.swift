// A macro: ordered steps, optional app binding, optional hotkey. MacroStore
// persists these as JSON.

import Foundation

nonisolated struct Macro: Codable, Identifiable, Hashable, Sendable {
    /// SF Symbols that look decent next to a macro name.
    static let availableSymbols: [String] = [
        "square.stack.3d.up.fill",
        "bolt.fill",
        "target",
        "scope",
        "gamecontroller.fill",
        "cursorarrow.click.2",
        "sparkles",
        "wand.and.stars",
        "die.face.5.fill",
        "flag.fill",
        "flag.checkered",
        "trophy.fill",
        "crown.fill",
        "shield.fill",
        "shield.lefthalf.filled",
        "hammer.fill",
        "wrench.fill",
        "gearshape.fill",
        "cpu.fill",
        "terminal.fill",
        "key.fill",
        "lock.fill",
        "diamond.fill",
        "leaf.fill",
        "moon.fill",
        "sun.max.fill",
        "flame.fill",
        "drop.fill",
        "snowflake",
        "atom",
        "star.fill",
        "heart.fill",
        "bell.fill",
        "bookmark.fill",
        "tag.fill",
        "pin.fill",
        "eye.fill",
        "magnifyingglass",
        "timer",
        "alarm.fill",
        "clock.fill",
        "stopwatch.fill",
        "hourglass",
        "tortoise.fill",
        "hare.fill",
        "pawprint.fill",
        "party.popper.fill",
        "gift.fill",
        "megaphone.fill",
        "ant.fill",
    ]

    var id: UUID
    var name: String
    /// Sidebar and editor icon.
    var symbol: String
    var steps: [MacroStep]
    var windowFilter: WindowFilter?
    var hotkey: Hotkey?
    /// How many times the step list runs. 0 = forever.
    var loopCount: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String = Macro.availableSymbols[0],
        steps: [MacroStep] = [],
        windowFilter: WindowFilter? = nil,
        hotkey: Hotkey? = nil,
        loopCount: Int = 1,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.steps = steps
        self.windowFilter = windowFilter
        self.hotkey = hotkey
        self.loopCount = loopCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Copy with a new id and "(copy)" appended.
    func duplicated() -> Macro {
        var copy = self
        copy.id = UUID()
        copy.name += " (copy)"
        copy.createdAt = .now
        copy.updatedAt = .now
        return copy
    }

    // Older saved macros have no `symbol`.
    enum CodingKeys: String, CodingKey {
        case id, name, symbol, steps, windowFilter, hotkey, loopCount, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? Macro.availableSymbols[0]
        self.steps = try c.decode([MacroStep].self, forKey: .steps)
        self.windowFilter = try c.decodeIfPresent(WindowFilter.self, forKey: .windowFilter)
        self.hotkey = try c.decodeIfPresent(Hotkey.self, forKey: .hotkey)
        self.loopCount = try c.decode(Int.self, forKey: .loopCount)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }
}

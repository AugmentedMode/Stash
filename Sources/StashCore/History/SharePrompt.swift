import Foundation

/// Decides when Stash asks, once, whether someone would like to share it.
///
/// The ask waits until Stash has clearly helped: the person has brought back an
/// older clip (not just their latest copy) at least `recallsNeeded` times, on at
/// least `daysNeeded` different days. Everything is counted on this Mac only.
public struct SharePrompt: Codable, Equatable {
    public static let recallsNeeded = 10
    public static let daysNeeded = 3
    /// How long "Maybe later" waits before the one remaining ask.
    public static let snooze: TimeInterval = 21 * 24 * 60 * 60

    public private(set) var recalls = 0
    public private(set) var recallDays: Set<String> = []
    public private(set) var snoozedUntil: Date?
    public private(set) var laterCount = 0
    public private(set) var finished = false

    public init() {}

    /// Records that a clip was pasted or copied back. `position` is its index in
    /// history, newest first; the newest clip is what ⌘V would paste anyway.
    public mutating func recordRecall(position: Int, at date: Date = Date(), calendar: Calendar = .current) {
        guard position > 0, !finished else { return }
        recalls += 1
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        recallDays.insert("\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)")
    }

    public func shouldShow(at date: Date = Date()) -> Bool {
        guard !finished, recalls >= Self.recallsNeeded, recallDays.count >= Self.daysNeeded else {
            return false
        }
        if let snoozedUntil { return date >= snoozedUntil }
        return true
    }

    /// "Maybe later": ask one more time after a few weeks, then never again.
    public mutating func later(at date: Date = Date()) {
        laterCount += 1
        if laterCount >= 2 { finished = true } else { snoozedUntil = date.addingTimeInterval(Self.snooze) }
    }

    /// Shared, starred or closed: don't ask again.
    public mutating func done() { finished = true }
}

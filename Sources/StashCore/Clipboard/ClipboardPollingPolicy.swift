import Foundation

public enum ClipboardPollingPolicy {
    public static func interval(paused: Bool, suspended: Bool, lowPower: Bool) -> TimeInterval? {
        guard !paused, !suspended else { return nil }
        return lowPower ? 1.2 : 0.6
    }
}

import Foundation

public enum Suppression: Equatable {
    case snoozed
    /// The user already presses this binding today, or ignored it repeatedly: quiet until tomorrow.
    case mutedToday
    case cooldown
    case rateLimited
}

public enum SuggestionDecision: Equatable {
    case show
    case suppressed(Suppression)
}

/// Decides whether a suggestion may be shown. Time comes from an injected clock.
public struct SuggestionPolicy {
    public struct Limits {
        public var perSuggestionCooldown: TimeInterval = 30
        public var minimumToastInterval: TimeInterval = 5
        /// How long the user has to press the suggested binding before the suggestion counts as ignored.
        public var followUpWindow: TimeInterval = 60
        public var ignoredBeforeBackOff = 3

        public init() {}
    }

    private let clock: () -> Date
    private let calendar: Calendar
    private let limits: Limits

    private var lastShown: [String: Date] = [:]
    private var lastToast: Date?
    private var pending: [String: Date] = [:]
    private var ignoredCount: [String: Int] = [:]
    private var mutedOn: [String: Date] = [:]
    /// Keys of the second binding of a pair, mapped to the key of the suggestion they belong to.
    private var pairedWith: [String: String] = [:]
    public private(set) var snoozedUntil: Date?

    public init(limits: Limits = Limits(), calendar: Calendar = .current, clock: @escaping () -> Date = Date.init) {
        self.limits = limits
        self.calendar = calendar
        self.clock = clock
    }

    public var isSnoozed: Bool { snoozedUntil.map { $0 > clock() } ?? false }

    public mutating func snooze(for duration: TimeInterval = 3600) {
        snoozedUntil = clock().addingTimeInterval(duration)
    }

    public mutating func resume() { snoozedUntil = nil }

    /// Asks whether `suggestion` may be shown now. A `.show` answer counts as shown.
    public mutating func consider(_ suggestion: Suggestion) -> SuggestionDecision {
        let now = clock()
        let key = suggestion.key
        expirePending(now: now)

        if isSnoozed { return .suppressed(.snoozed) }
        if let day = mutedOn[key], calendar.isDate(day, inSameDayAs: now) { return .suppressed(.mutedToday) }
        if let last = lastShown[key], now.timeIntervalSince(last) < limits.perSuggestionCooldown { return .suppressed(.cooldown) }
        if let last = lastToast, now.timeIntervalSince(last) < limits.minimumToastInterval { return .suppressed(.rateLimited) }

        lastShown[key] = now
        pairedWith[key] = nil
        for related in suggestion.relatedKeys where related != key { pairedWith[related] = key }
        lastToast = now
        pending[key] = now
        return .show
    }

    /// The user pressed a binding (a `binding-triggered` event). If it was suggested, or is the other half of a suggested pair, they have learned it.
    public mutating func recordKeyboard(binding raw: String) {
        let now = clock()
        let pressed = KeyCombo(raw: raw).canonical
        let key = pairedWith[pressed] ?? pressed
        expirePending(now: now)
        guard lastShown[key] != nil else { return }
        pending[key] = nil
        ignoredCount[key] = 0
        mutedOn[key] = now
    }

    /// Suggestions left unanswered past the follow-up window count as ignored; enough of them back off for the day.
    private mutating func expirePending(now: Date) {
        for (key, shownAt) in pending where now.timeIntervalSince(shownAt) >= limits.followUpWindow {
            pending[key] = nil
            let count = (ignoredCount[key] ?? 0) + 1
            ignoredCount[key] = count
            if count >= limits.ignoredBeforeBackOff {
                ignoredCount[key] = 0
                mutedOn[key] = now
            }
        }
    }
}

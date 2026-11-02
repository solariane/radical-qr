//
//  ReviewPrompter.swift
//
//  Same file in Radical QR and Phone Number Cleaner — edit both. Each app
//  declares its own `ReviewPrompter.shared` with the rules that suit it.
//

import Foundation

/// Decides when to show the system review prompt, from usage counted on this
/// device only: five values in `UserDefaults`, no identifier, no network.
///
/// The app reports *value moments* (a code saved, a book cleaned) and
/// *friction* (an error, the paywall), then calls `requestIfDue` at a calm
/// point — a sheet just closed, a confirmation just shown. Never at launch,
/// never mid-edit, never in a session that hit friction.
///
/// Apple still caps the prompt at three a year and may show nothing, so a
/// "Rate" button the user taps must open `?action=write-review` instead of
/// calling `requestReview`: it would look broken and spend one of the three.
///
/// Not `@MainActor`, on purpose: an isolated class gets an isolated deinit,
/// whose back-deployment shim crashes on iOS 18 when XCTest releases one. The
/// apps reach it through `shared`, which their default MainActor isolation
/// already confines to the main thread.
nonisolated final class ReviewPrompter {
    struct Rules: Sendable {
        /// Value moments counted before the first ask.
        var minimumMoments: Int
        /// Distinct days with at least one value moment.
        var minimumActiveDays: Int
        /// Calendar days since the first value moment.
        var minimumDaysSinceFirstUse: Int
        /// Calendar days between two asks, whatever the version.
        var daysBetweenAsks = 120
    }

    private enum Key {
        static let firstUse = "review.firstUse"
        static let moments = "review.moments"
        static let activeDays = "review.activeDays"
        static let lastActiveDay = "review.lastActiveDay"
        static let lastAsk = "review.lastAsk"
        static let lastAskVersion = "review.lastAskVersion"
        /// Debug only: launch with `-review.alwaysAsk YES` to see the prompt.
        static let alwaysAsk = "review.alwaysAsk"
    }

    let rules: Rules
    private let defaults: UserDefaults
    private let version: String
    private let calendar: Calendar
    private let now: () -> Date

    /// Lives as long as the process: an error or the paywall puts the ask off
    /// to another day, never to another tap.
    private(set) var hadFriction = false

    init(
        rules: Rules,
        defaults: UserDefaults = .standard,
        version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.rules = rules
        self.defaults = defaults
        self.version = version
        self.calendar = calendar
        self.now = now
    }

    // MARK: - Reporting

    func recordValueMoment() {
        let today = now()
        if defaults.object(forKey: Key.firstUse) == nil {
            defaults.set(today, forKey: Key.firstUse)
        }
        defaults.set(defaults.integer(forKey: Key.moments) + 1, forKey: Key.moments)

        let lastDay = defaults.object(forKey: Key.lastActiveDay) as? Date
        if lastDay.map({ !calendar.isDate($0, inSameDayAs: today) }) ?? true {
            defaults.set(defaults.integer(forKey: Key.activeDays) + 1, forKey: Key.activeDays)
            defaults.set(today, forKey: Key.lastActiveDay)
        }
    }

    func recordFriction() {
        hadFriction = true
    }

    // MARK: - Asking

    var isDue: Bool {
        #if DEBUG
        if defaults.bool(forKey: Key.alwaysAsk) { return true }
        #endif
        guard !hadFriction,
              defaults.integer(forKey: Key.moments) >= rules.minimumMoments,
              defaults.integer(forKey: Key.activeDays) >= rules.minimumActiveDays,
              let firstUse = defaults.object(forKey: Key.firstUse) as? Date,
              days(since: firstUse) >= rules.minimumDaysSinceFirstUse,
              defaults.string(forKey: Key.lastAskVersion) != version
        else { return false }

        if let lastAsk = defaults.object(forKey: Key.lastAsk) as? Date {
            return days(since: lastAsk) >= rules.daysBetweenAsks
        }
        return true
    }

    /// Runs `request` — the view's `requestReview` — when the rules hold, and
    /// remembers the ask whether or not the system shows anything.
    func requestIfDue(_ request: () -> Void) {
        guard isDue else { return }
        defaults.set(now(), forKey: Key.lastAsk)
        defaults.set(version, forKey: Key.lastAskVersion)
        request()
    }

    private func days(since date: Date) -> Int {
        let from = calendar.startOfDay(for: date)
        let to = calendar.startOfDay(for: now())
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}

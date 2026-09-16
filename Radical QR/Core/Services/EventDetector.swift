import Foundation

/// A free-text input that reads as an appointment, and how sure we are of it.
nonisolated struct EventDetection: Equatable, Sendable {
    typealias Confidence = ContentDetection.Confidence

    let draft: EventDraft
    let confidence: Confidence
}

/// Turns "21h mercredi 16/09" into an event draft.
///
/// Dates are found by `NSDataDetector` — on-device, no network — which reads
/// English, French, German, Spanish, Italian and Portuguese phrasing and
/// numeric dates in any script. It does not read 年月日 dates, so those have
/// a small parser of their own. A street address becomes the location, and
/// whatever the date, address and link leave behind becomes the title.
nonisolated enum EventDetector {
    /// Long pasted prose that happens to mention a date is not an event.
    private static let maxInputLength = 280
    private static let maxHighConfidenceTitle = 60
    private static let maxSuggestedTitle = 100

    /// - Parameter requireFullCoverage: the input already reads as another type
    ///   (a phone number for "16.09.2026"); only a date that is the whole input wins.
    static func detect(in input: String, requireFullCoverage: Bool = false, now: Date = Date()) -> EventDetection? {
        let original = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty, original.count <= maxInputLength else { return nil }
        // The detectors are read with CJK and Arabic punctuation as its ASCII twin —
        // "20時、350 Fifth Avenue" hides the address otherwise. Same length, so
        // every range found still points into the original, which the title and
        // the location are cut from.
        let text = ScriptPunctuation.asciiAligned(original)
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        guard var found = CJKDateParser.find(in: text, now: now) ?? detectorDate(in: text, range: fullRange) else {
            return nil
        }
        // Before reading the date: the address may hand back words it took from it.
        let address = firstAddress(in: text, range: fullRange, date: &found)

        let matchedText = nsText.substring(with: found.range)
        // A date needs a number to be one: "demain" alone in "merci pour demain" is prose.
        guard matchedText.rangeOfCharacter(from: .decimalDigits) != nil else { return nil }

        var coveredRanges = [found.range]
        let link = firstLink(in: text, range: fullRange, excluding: [found.range] + (address.map { [$0.range] } ?? []))
        if let link { coveredRanges.append(link.range) }
        if let address { coveredRanges.append(address.range) }

        let dateCoverage = Double(nonSpaceCount(matchedText)) / Double(max(nonSpaceCount(text), 1))
        if requireFullCoverage && dateCoverage < 0.9 { return nil }

        let hasTime = found.hasTime ?? TimeExpression.isExplicit(in: matchedText, date: found.date)
        let draft = makeDraft(
            date: found.date,
            duration: found.duration,
            hasTime: hasTime,
            title: TitleCleaner.title(from: original, removing: coveredRanges),
            location: address.map { singleLine((original as NSString).substring(with: $0.range)) } ?? "",
            url: link?.url.absoluteString ?? ""
        )

        // An address pasted from a signature spans two or three lines on its own;
        // it should not make the text look like prose.
        let textWithoutAddress = address.map { nsText.replacingCharacters(in: $0.range, with: " ") } ?? text
        let lineCount = textWithoutAddress.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        guard draft.title.count <= maxSuggestedTitle, lineCount <= 4 else { return nil }

        let startOfToday = Calendar.current.startOfDay(for: now)
        let isClear = hasTime
            && TimeExpression.namesADay(matchedText)
            && found.alternatives == 0
            && draft.start >= startOfToday
            && draft.title.count <= maxHighConfidenceTitle
            && lineCount <= 3

        return EventDetection(draft: draft, confidence: isClear ? .high : .medium)
    }

    // MARK: - Pieces

    struct FoundDate: Sendable {
        let range: NSRange
        let date: Date
        let duration: TimeInterval
        /// Known for parsers that read the time themselves; `nil` asks `TimeExpression`.
        let hasTime: Bool?
        /// Other dates in the same text — two dates make the reading ambiguous.
        let alternatives: Int
    }

    private static func detectorDate(in text: String, range: NSRange) -> FoundDate? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        var matches = detector.matches(in: text, range: range).filter { $0.date != nil }
        var offset = 0
        if matches.isEmpty {
            // The detector can lose a plain date to what precedes it: "salle 3 bâtiment B
            // 16/09 10h" finds nothing, "16/09 10h" is found. Retry without the leading words.
            let words = wordPattern?.matches(in: text, range: range).dropFirst().prefix(12) ?? []
            for word in words {
                let suffix = (text as NSString).substring(from: word.range.location)
                let found = detector.matches(in: suffix, range: NSRange(location: 0, length: (suffix as NSString).length))
                    .filter { $0.date != nil }
                if !found.isEmpty {
                    matches = found
                    offset = word.range.location
                    break
                }
            }
        }
        guard var longest = matches.max(by: { $0.range.length < $1.range.length }) else { return nil }
        if offset == 0, let better = reclaimTime(from: longest, in: text, detector: detector) {
            longest = better
        }
        guard let date = longest.date else { return nil }
        return FoundDate(
            range: NSRange(location: longest.range.location + offset, length: longest.range.length),
            date: date,
            duration: longest.duration,
            hasTime: nil,
            alternatives: matches.count - 1
        )
    }

    /// The detector reads a meal as a time of day: "dîner samedi 20h" becomes
    /// "dîner samedi" at 19:00, and the "20h" written after it is lost. When the
    /// date it took names no time, the first word is masked and the text read
    /// again; if that finds a date with a time, it wins, and the meal stays in
    /// the title where it belongs.
    private static func reclaimTime(from match: NSTextCheckingResult, in text: String, detector: NSDataDetector) -> NSTextCheckingResult? {
        let nsText = text as NSString
        guard let firstWord = wordPattern?.firstMatch(in: text, range: match.range),
              firstWord.range.length < match.range.length else { return nil }
        let startsWithMeal = mealWords.contains(nsText.substring(with: firstWord.range).lowercased()
            .trimmingCharacters(in: .punctuationCharacters))
        // "Dinner Saturday 8pm" has its time, but "Dinner" is still the title.
        guard startsWithMeal || !TimeExpression.matches(in: nsText.substring(with: match.range)) else { return nil }
        // Same length, so every range found still points into the original text.
        let masked = nsText.replacingCharacters(in: firstWord.range, with: String(repeating: " ", count: firstWord.range.length))
        let retry = detector.matches(in: masked, range: NSRange(location: 0, length: nsText.length))
            .filter { $0.date != nil && TimeExpression.matches(in: nsText.substring(with: $0.range)) }
        return retry.max(by: { $0.range.length < $1.range.length })
    }

    /// Meals the detector reads as a time of day, in the app's languages.
    private static let mealWords: Set<String> = [
        "breakfast", "brunch", "lunch", "dinner", "supper",
        "petit-déjeuner", "déjeuner", "dîner", "souper", "goûter",
        "frühstück", "mittagessen", "abendessen",
        "desayuno", "almuerzo", "comida", "cena",
        "colazione", "pranzo",
        "café", "almoço", "jantar",
        "朝食", "昼食", "夕食", "早餐", "午餐", "晚餐"
    ]

    private static let wordPattern = try? NSRegularExpression(pattern: #"\S+"#)

    /// Drops the spaces and punctuation a range ends with.
    private static func trimmingTrailingPunctuation(_ range: NSRange, in text: NSString) -> NSRange {
        var trimmed = range
        while trimmed.length > 0,
              let last = Unicode.Scalar(text.character(at: NSMaxRange(trimmed) - 1)),
              TitleCleaner.edgePunctuation.contains(last) {
            trimmed.length -= 1
        }
        return trimmed
    }

    /// Reads `text` as a date only if the detector takes all of it.
    private static func wholeDate(_ text: String) -> NSTextCheckingResult? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let whole = NSRange(location: 0, length: (text as NSString).length)
        return detector.matches(in: text, range: whole).first { $0.range == whole && $0.date != nil }
    }

    private static func firstLink(in text: String, range: NSRange, excluding taken: [NSRange]) -> (range: NSRange, url: URL)? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        for match in detector.matches(in: text, range: range) {
            guard let url = match.url,
                  let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
                  !taken.contains(where: { NSIntersectionRange(match.range, $0).length > 0 }) else { continue }
            return (match.range, url)
        }
        return nil
    }

    /// The first street address that is not the date itself, written on one line.
    ///
    /// The address detector reads greedily: in "221B Baker Street, London Friday 8pm"
    /// it takes "London Friday" for the city and leaves the date only "8pm". When
    /// the address's last words and the date that follows read as one date, they
    /// go back to the date.
    private static func firstAddress(in text: String, range: NSRange, date: inout FoundDate) -> (range: NSRange, location: String)? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue) else {
            return nil
        }
        let nsText = text as NSString
        if let lent = houseNumberTakenByDate(in: nsText, date: date, detector: detector) {
            date = lent.date
            return (lent.address, singleLine(nsText.substring(with: lent.address)))
        }
        for match in detector.matches(in: text, range: range) {
            guard NSIntersectionRange(match.range, date.range).length == 0 else { continue }
            var addressRange = match.range
            if date.hasTime == nil, let reclaimed = reclaimDateWords(in: nsText, address: addressRange, date: date) {
                addressRange = reclaimed.address
                date = reclaimed.date
            }
            let location = singleLine(nsText.substring(with: addressRange))
            guard !location.isEmpty else { continue }
            return (addressRange, location)
        }
        return nil
    }

    /// "12 rue de Rivoli⏎75001 Paris" → "12 rue de Rivoli, 75001 Paris".
    private static func singleLine(_ address: String) -> String {
        address
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: TitleCleaner.edgePunctuation) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .joined(separator: " ")
    }

    /// The other greedy reading: in "16/09 21h 10 rue de la Paix" the date takes the
    /// house number for minutes (21:10). When an address starts at the date's last
    /// word and the rest still reads as a date, the number goes to the address.
    private static func houseNumberTakenByDate(
        in text: NSString, date: FoundDate, detector: NSDataDetector
    ) -> (address: NSRange, date: FoundDate)? {
        guard date.hasTime == nil,
              let last = wordPattern?.matches(in: text as String, range: date.range).last,
              last.range.location > date.range.location,
              text.substring(with: last.range).allSatisfy(\.isNumber) else { return nil }

        let tail = NSRange(location: last.range.location, length: text.length - last.range.location)
        let tailText = text.substring(with: tail)
        guard let address = detector.matches(in: tailText, range: NSRange(location: 0, length: tail.length))
                .first(where: { $0.range.location == 0 }) else { return nil }

        let shortened = trimmingTrailingPunctuation(
            NSRange(location: date.range.location, length: last.range.location - date.range.location), in: text
        )
        guard shortened.length > 0,
              let match = wholeDate(text.substring(with: shortened)),
              let newDate = match.date else { return nil }

        return (
            NSRange(location: tail.location, length: address.range.length),
            FoundDate(range: shortened, date: newDate, duration: match.duration, hasTime: nil, alternatives: date.alternatives)
        )
    }

    private static func reclaimDateWords(in text: NSString, address: NSRange, date: FoundDate) -> (address: NSRange, date: FoundDate)? {
        let addressEnd = NSMaxRange(address)
        guard addressEnd <= date.range.location,
              text.substring(with: NSRange(location: addressEnd, length: date.range.location - addressEnd))
                .trimmingCharacters(in: .whitespaces).isEmpty,
              let wordPattern else {
            return nil
        }
        // At most the last two words: a weekday, or "next Friday".
        let words = wordPattern.matches(in: text as String, range: address).suffix(2)
        for word in words where word.range.location > address.location {
            let candidate = NSRange(location: word.range.location, length: NSMaxRange(date.range) - word.range.location)
            guard let match = wholeDate(text.substring(with: candidate)), let newDate = match.date else { continue }

            // What stays an address, minus the comma or space that led into the date.
            let kept = trimmingTrailingPunctuation(
                NSRange(location: address.location, length: word.range.location - address.location), in: text
            )
            guard kept.length > 0 else { return nil }
            let found = FoundDate(
                range: candidate, date: newDate, duration: match.duration, hasTime: nil, alternatives: date.alternatives
            )
            return (kept, found)
        }
        return nil
    }

    private static func makeDraft(
        date: Date, duration: TimeInterval, hasTime: Bool, title: String, location: String, url: String
    ) -> EventDraft {
        let calendar = Calendar.current
        if hasTime {
            let end = date.addingTimeInterval(duration > 0 ? duration : EventDraft.defaultDuration)
            return EventDraft(title: title, start: date, end: end, isAllDay: false, location: location, url: url)
        }
        let day = calendar.startOfDay(for: date)
        let lastDay = calendar.startOfDay(for: date.addingTimeInterval(max(duration, 0)))
        return EventDraft(title: title, start: day, end: max(lastDay, day), isAllDay: true, location: location, url: url)
    }

    private static func nonSpaceCount(_ text: String) -> Int {
        text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.count
    }
}

// MARK: - Time expressions

/// What `NSDataDetector` does not say: whether the text named a time (it fills
/// in noon when it did not) and whether it named a day (it fills in today).
nonisolated enum TimeExpression {
    /// Times as written in the app's languages: 21h, 21h30, 21:00, 9pm, 15 Uhr,
    /// 21時, 9点, 9 बजे, الساعة 9, and the words for noon.
    private static let pattern = try? NSRegularExpression(
        pattern: #"\d{1,2}\s*:\s*\d{2}|\d{1,2}(?:[.:]\d{2})?\s*uhr|\d{1,2}\s*h(?:\s*\d{2})?(?!\p{L})|\d{1,2}(?:[.:]\d{2})?\s*[ap]\.?\s?m\b\.?|\d{1,2}\s*[時时点點](?:\s*\d{1,2}\s*分|半)?|\d{1,2}\s*बजे|الساعة\s*\d{1,2}|\b(?:noon|midday|midi|mittags?|mezzogiorno|mediod[ií]a|meio-dia)\b|正午|中午"#,
        options: [.caseInsensitive]
    )

    /// Words that sit inside a date phrase without naming a day.
    private static let connectors: Set<String> = [
        "alle", "dalle", "from", "until", "gegen", "vers", "partir", "desde", "hasta", "entre", "about"
    ]

    /// A date the detector put at exactly noon may be a real 12:00 or a missing time.
    static func isExplicit(in text: String, date: Date) -> Bool {
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        if parts.hour != 12 || parts.minute != 0 || parts.second != 0 { return true }
        return matches(in: text)
    }

    static func matches(in text: String) -> Bool {
        guard let pattern else { return false }
        return pattern.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    /// "21h" names no day, "mercredi 21h", "demain 21h" and "16/09 21h" do.
    static func namesADay(_ text: String) -> Bool {
        guard let pattern else { return true }
        let stripped = pattern.stringByReplacingMatches(
            in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: " "
        )
        if stripped.rangeOfCharacter(from: .decimalDigits) != nil { return true }
        let words = stripped.lowercased().components(separatedBy: CharacterSet.letters.inverted)
        return words.contains { word in
            guard !connectors.contains(word) else { return false }
            // Four Latin letters is the shortest weekday or "today" worth trusting;
            // a single ideograph (今, 明) already is one.
            let isLatin = word.unicodeScalars.allSatisfy { $0.value < 0x250 }
            return isLatin ? word.count >= 4 : !word.isEmpty
        }
    }
}

// MARK: - Title

/// What remains once the date and the link are taken out, minus the glue
/// words that only made sense next to them ("rdv avec Paul le …").
nonisolated enum TitleCleaner {
    private static let edgeWords: Set<String> = [
        "le", "la", "à", "a", "au", "du", "de", "des", "ce", "pour",
        "on", "at", "the", "in", "from",
        "am", "um", "ab", "den", "vom", "im", "an",
        "el", "en", "los", "las", "para",
        "il", "alle", "dalle", "per",
        "em", "às", "no", "na"
    ]

    static let edgePunctuation = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: ",;:–—-·|/@()[]•.!?，、。；：！？（）「」،؛؟"))

    static func title(from text: String, removing ranges: [NSRange]) -> String {
        var remaining = text as NSString
        // Replace back to front so earlier ranges keep their offsets.
        for range in ranges.sorted(by: { $0.location > $1.location }) {
            remaining = remaining.replacingCharacters(in: range, with: " ") as NSString
        }
        let tokens = (remaining as String)
            .split(whereSeparator: \.isWhitespace)
            .filter { !$0.trimmingCharacters(in: edgePunctuation).isEmpty }
        func isGlue(_ token: Substring) -> Bool {
            edgeWords.contains(token.trimmingCharacters(in: edgePunctuation).lowercased())
        }

        var kept = tokens[...]
        while let last = kept.last, isGlue(last) { kept.removeLast() }
        while let first = kept.first, isGlue(first) { kept.removeFirst() }

        // Joined token by token, so inner punctuation ("Paul, Marie") survives.
        return kept.joined(separator: " ").trimmingCharacters(in: edgePunctuation)
    }
}

// MARK: - 年月日 dates

/// "2026年9月16日 21時", "9月16日(水) 午後9時", "9月16日 下午3点半".
/// `NSDataDetector` reads only the time out of these and dates it today.
nonisolated enum CJKDateParser {
    private static let pattern = try? NSRegularExpression(
        pattern: #"(?:(\d{4})\s*年\s*)?(\d{1,2})\s*月\s*(\d{1,2})\s*[日号號](?:\s*[(（]?\s*(?:星期|周|週)?[月火水木金土日一二三四五六天]\s*[)）]?)?(?:\s*(午前|午後|上午|下午|晚上|夜)?\s*(?:(\d{1,2})\s*[時时点點](?:\s*(\d{1,2})\s*分|\s*(半))?|(\d{1,2}):(\d{2})))?"#
    )

    static func find(in text: String, now: Date) -> EventDetector.FoundDate? {
        guard let pattern else { return nil }
        let nsText = text as NSString
        guard let match = pattern.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) else {
            return nil
        }
        func group(_ index: Int) -> String? {
            let range = match.range(at: index)
            return range.location == NSNotFound ? nil : nsText.substring(with: range)
        }

        // Gregorian whatever the device uses: 2026年 is not a Reiwa year.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        var parts = DateComponents()
        parts.month = group(2).flatMap { Int($0) }
        parts.day = group(3).flatMap { Int($0) }

        var hour = group(5).flatMap { Int($0) } ?? group(8).flatMap { Int($0) }
        let minute = group(6).flatMap { Int($0) } ?? group(9).flatMap { Int($0) } ?? (group(7) != nil ? 30 : 0)
        if let h = hour, h < 12, let period = group(4), ["午後", "下午", "晚上", "夜"].contains(period) {
            hour = h + 12
        }
        parts.hour = hour ?? 0
        parts.minute = hour == nil ? 0 : minute

        let explicitYear = group(1).flatMap { Int($0) }
        parts.year = explicitYear ?? calendar.component(.year, from: now)
        guard var date = calendar.date(from: parts),
              calendar.component(.month, from: date) == parts.month else { return nil }
        // No year given and the day has passed: the next one is meant.
        if explicitYear == nil, date < calendar.startOfDay(for: now) {
            date = calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }

        return EventDetector.FoundDate(
            range: match.range,
            date: date,
            duration: 0,
            hasTime: hour != nil,
            alternatives: 0
        )
    }
}

// MARK: - Punctuation in other scripts

/// Full-width and Arabic punctuation, read as the ASCII the detectors know.
nonisolated enum ScriptPunctuation {
    private static let twins: [Character: Character] = [
        "，": ",", "、": ",", "،": ",", "；": ";", "؛": ";", "：": ":", "（": "(", "）": ")",
    ]

    /// Same UTF-16 length as the input: every twin is one code unit, like the original.
    static func asciiAligned(_ text: String) -> String {
        String(text.map { twins[$0] ?? $0 })
    }
}

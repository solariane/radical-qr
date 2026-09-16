import Foundation

/// A calendar event the user can still edit, and the `VEVENT` block it encodes.
///
/// The QR content is always regenerated from the draft, so the generator never
/// has to parse free text twice. The encoding is the bare `BEGIN:VEVENT` block
/// the iOS camera and ZXing-based readers recognise as "add to calendar".
nonisolated struct EventDraft: Equatable, Sendable {
    var title: String = ""
    var start: Date
    /// Exclusive end for a timed event; the last day (inclusive) for an all-day one.
    var end: Date
    var isAllDay: Bool = false
    var location: String = ""
    var url: String = ""

    /// Default length when the source gave only a start.
    static let defaultDuration: TimeInterval = 3600

    init(title: String = "", start: Date, end: Date, isAllDay: Bool = false, location: String = "", url: String = "") {
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.url = url
    }

    // MARK: - Editing

    /// Moves the start and carries the end along, so the event keeps its length.
    mutating func moveStart(to newStart: Date) {
        let length = end.timeIntervalSince(start)
        start = newStart
        end = newStart.addingTimeInterval(max(length, 0))
    }

    /// An end before the start is not an event — clamp it.
    mutating func setEnd(_ newEnd: Date) {
        end = max(newEnd, start)
    }

    mutating func setAllDay(_ allDay: Bool, calendar: Calendar = .current) {
        guard allDay != isAllDay else { return }
        isAllDay = allDay
        if allDay {
            start = calendar.startOfDay(for: start)
            end = max(calendar.startOfDay(for: end), start)
        } else {
            // Nine o'clock is a better guess than midnight for a day that gains an hour.
            let day = calendar.startOfDay(for: start)
            start = calendar.date(byAdding: .hour, value: 9, to: day) ?? day
            end = start.addingTimeInterval(Self.defaultDuration)
        }
    }

    // MARK: - Encoding

    var icalendar: String {
        var lines = ["BEGIN:VEVENT"]
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            lines.append("SUMMARY:\(Self.escape(trimmedTitle))")
        }
        if isAllDay {
            // RFC 5545: an all-day DTEND is the day *after* the last one.
            let dayAfter = ICalendarDate.gregorian.date(byAdding: .day, value: 1, to: end) ?? end
            lines.append("DTSTART;VALUE=DATE:\(ICalendarDate.dayString(start))")
            lines.append("DTEND;VALUE=DATE:\(ICalendarDate.dayString(dayAfter))")
        } else {
            // UTC, so whoever scans it elsewhere sees the right local time.
            lines.append("DTSTART:\(ICalendarDate.utcString(start))")
            lines.append("DTEND:\(ICalendarDate.utcString(end))")
        }
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLocation.isEmpty {
            lines.append("LOCATION:\(Self.escape(trimmedLocation))")
        }
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedURL.isEmpty {
            lines.append("URL:\(trimmedURL)")
        }
        lines.append("END:VEVENT")
        return lines.joined(separator: "\r\n")
    }

    // MARK: - Decoding

    /// Properties this editor round-trips without loss. Anything else — a
    /// VTIMEZONE, an RRULE, attendees — means the block came from somewhere
    /// richer, and editing it here would silently drop that part.
    private static let editableProperties: Set<String> = ["SUMMARY", "DTSTART", "DTEND", "LOCATION", "URL"]

    /// Reads back a block this editor could have written; `nil` for anything richer.
    init?(icalendar: String) {
        let lines = icalendar
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.first?.uppercased() == "BEGIN:VEVENT",
              lines.last?.uppercased() == "END:VEVENT" else { return nil }

        var title = "", location = "", url = ""
        var start: (date: Date, isAllDay: Bool)?
        var end: (date: Date, isAllDay: Bool)?

        for line in lines.dropFirst().dropLast() {
            guard let colon = line.firstIndex(of: ":") else { return nil }
            let head = line[..<colon]
            let name = head.split(separator: ";").first.map { String($0).uppercased() } ?? ""
            let value = String(line[line.index(after: colon)...])
            guard Self.editableProperties.contains(name) else { return nil }
            switch name {
            case "SUMMARY": title = Self.unescape(value)
            case "LOCATION": location = Self.unescape(value)
            case "URL": url = value
            case "DTSTART": start = ICalendarDate.parse(line)
            case "DTEND": end = ICalendarDate.parse(line)
            default: break
            }
        }

        guard let start else { return nil }
        self.title = title
        self.location = location
        self.url = url
        self.isAllDay = start.isAllDay
        self.start = start.date
        if start.isAllDay {
            let lastDay = end.flatMap { ICalendarDate.gregorian.date(byAdding: .day, value: -1, to: $0.date) }
            self.end = max(lastDay ?? start.date, start.date)
        } else {
            self.end = max(end?.date ?? start.date.addingTimeInterval(Self.defaultDuration), start.date)
        }
    }

    // MARK: - Text escaping (RFC 5545 §3.3.11)

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    static func unescape(_ text: String) -> String {
        var result = ""
        var iterator = text.makeIterator()
        while let character = iterator.next() {
            guard character == "\\", let next = iterator.next() else {
                result.append(character)
                continue
            }
            result.append(next == "n" || next == "N" ? "\n" : next)
        }
        return result
    }
}

// MARK: - iCalendar dates

/// Date values in iCalendar are always Gregorian with ASCII digits, whatever the
/// device runs: a Japanese-calendar or Arabic-digit locale must not leak into them.
nonisolated enum ICalendarDate {
    static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = .current
        return calendar
    }()

    static func utcString(_ date: Date) -> String {
        formatter("yyyyMMdd'T'HHmmss'Z'", timeZone: TimeZone(identifier: "UTC")).string(from: date)
    }

    static func dayString(_ date: Date) -> String {
        formatter("yyyyMMdd", timeZone: .current).string(from: date)
    }

    /// Parses a whole `DTSTART…:value` line, honouring `VALUE=DATE`, a `Z`
    /// suffix and a `TZID` parameter. Floating times are read as local.
    static func parse(_ line: String) -> (date: Date, isAllDay: Bool)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let parameters = line[..<colon].uppercased()
        let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)

        if value.count == 8 || (parameters.contains("VALUE=DATE") && !parameters.contains("VALUE=DATE-TIME")) {
            guard let date = formatter("yyyyMMdd", timeZone: .current).date(from: String(value.prefix(8))) else {
                return nil
            }
            return (date, true)
        }

        var zone = TimeZone.current
        if value.hasSuffix("Z") {
            zone = TimeZone(identifier: "UTC") ?? zone
        } else if let tzRange = line[..<colon].range(of: "TZID=", options: .caseInsensitive) {
            let identifier = line[tzRange.upperBound..<colon].split(separator: ";").first.map(String.init) ?? ""
            zone = TimeZone(identifier: identifier) ?? zone
        }
        let digits = value.replacingOccurrences(of: "Z", with: "")
        guard let date = formatter("yyyyMMdd'T'HHmmss", timeZone: zone).date(from: digits) else { return nil }
        return (date, false)
    }

    private static func formatter(_ format: String, timeZone: TimeZone?) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }
}

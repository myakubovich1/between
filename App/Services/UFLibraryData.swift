import Foundation

/// Public read-only feeds used by UF's own library pages. No Supabase or sign-in required.
actor UFLibraryData: OfficialOccupancyProvider {
    static let hoursURL = URL(string: "https://api3.libcal.com/api_hours_grid.php?iid=6&format=json&weeks=2")!
    static let sourceURL = URL(string: "https://www.uflib.ufl.edu/status/")!
    static let locations: [String: Int] = ["afa": 8626, "education": 8627, "health": 8871, "west": 7728, "marston": 8622, "smathers": 8625]
    // Public display identifiers embedded in UF's status page; these are not API credentials.
    static let displays: [String: String] = ["west": "6be1325f", "marston": "6d60eb03", "health": "dc7c5f6a", "afa": "bb2a5b5e", "education": "53b6c442", "smathers": "7cbdd017"]
    private var cachedHours: [String: Hours] = [:]
    private var hoursFetched: Date?
    private var counts: [String: OfficialOccupancy] = [:]
    private var attemptedCounts: Date?

    func observation(for placeID: String) async throws -> OfficialOccupancy? {
        await occupancy()[placeID]
    }
    private func fetch(_ url: URL, maxBytes: Int) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.setValue("Between/1.0 (UF library public display)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode), data.count <= maxBytes else { throw URLError(.badServerResponse) }
        return data
    }
    func hours(at now: Date = Date()) async throws -> [String: Hours] {
        if let hoursFetched, now.timeIntervalSince(hoursFetched) < 6 * 3600 { return cachedHours }
        let data = try await fetch(Self.hoursURL, maxBytes: 2_000_000)
        let parsed = try UFHoursParser.parse(data, fetchedAt: now)
        guard !parsed.isEmpty else { throw URLError(.cannotParseResponse) }
        cachedHours = parsed; hoursFetched = now
        return parsed
    }
    func occupancy(at now: Date = Date()) async -> [String: OfficialOccupancy] {
        // Share a bounded refresh across foreground timers, manual refresh and realtime updates.
        if let attemptedCounts, now.timeIntervalSince(attemptedCounts) < 60 { return counts }
        attemptedCounts = now
        await withTaskGroup(of: (String, OfficialOccupancy?).self) { group in
            for (place, display) in Self.displays {
                group.addTask {
                    do {
                        let url = URL(string: "https://display.safespace.io/value/live/\(display)")!
                        let data = try await self.fetch(url, maxBytes: 128)
                        let value = try Self.parseCount(data)
                        // The display exposes no sensor timestamp. Retrieval is never promoted to observation time.
                        return (place, OfficialOccupancy(sourceName: "UF Libraries · SafeSpace", count: value, percent: nil, observedAt: nil, retrievedAt: Date()))
                    } catch { return (place, nil) }
                }
            }
            for await (place, value) in group { if let value { counts[place] = value } }
        }
        return counts
    }
    nonisolated static func parseCount(_ data: Data) throws -> Int {
        guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
              text.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(text), (0...100_000).contains(value) else { throw URLError(.cannotParseResponse) }
        return value
    }
}

enum UFHoursParser {
    struct Grid: Decodable { var locations: [Location] }
    struct Location: Decodable { var lid: Int; var weeks: [[String: Day]] }
    struct Day: Decodable { var date: String; var times: Times }
    struct Times: Decodable { var status: String; var hours: [Range]? }
    struct Range: Decodable { var from: String; var to: String }
    static func parse(_ data: Data, fetchedAt: Date) throws -> [String: Hours] {
        let grid = try JSONDecoder().decode(Grid.self, from: data)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let dateFormat = DateFormatter(); dateFormat.calendar = calendar; dateFormat.timeZone = calendar.timeZone
        dateFormat.locale = Locale(identifier: "en_US_POSIX"); dateFormat.dateFormat = "yyyy-MM-dd"; dateFormat.isLenient = false
        func time(_ value: String, day: Date) -> Date? {
            let f = DateFormatter(); f.calendar = calendar; f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = calendar.timeZone; f.isLenient = false
            f.dateFormat = value.contains(":") ? "h:mma" : "ha"
            guard let parsed = f.date(from: value.trimmingCharacters(in: .whitespaces).uppercased()) else { return nil }
            let c = calendar.dateComponents([.hour, .minute], from: parsed)
            return calendar.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: day)
        }
        var output: [String: Hours] = [:]
        for (place, id) in UFLibraryData.locations {
            guard let location = grid.locations.first(where: { $0.lid == id }) else { continue }
            let days = location.weeks.flatMap { $0.values }.sorted { $0.date < $1.date }
            var intervals: [OpeningInterval] = []; var coverage: [OpeningInterval] = []
            for day in days {
                guard let start = dateFormat.date(from: day.date), let end = calendar.date(byAdding: .day, value: 1, to: start) else { continue }
                var dayIntervals: [OpeningInterval] = []
                switch day.times.status {
                case "closed": break
                case "24hours": dayIntervals = [.init(start: start, end: end)]
                case "open":
                    guard let ranges = day.times.hours, !ranges.isEmpty else { continue }
                    var valid = true
                    for range in ranges {
                        guard let from = time(range.from, day: start), var to = time(range.to, day: start) else { valid = false; break }
                        if to <= from { guard let next = calendar.date(byAdding: .day, value: 1, to: to) else { valid = false; break }; to = next }
                        // LibCal renders Marston's continuous Sunday opening as 11:59pm before 24 Hours.
                        // Bridge only that one-minute display convention when the next published day is 24hours.
                        if place == "marston", range.to.lowercased() == "11:59pm",
                           days.contains(where: { dateFormat.date(from: $0.date) == end && $0.times.status == "24hours" }) { to = end }
                        dayIntervals.append(.init(start: from, end: to))
                    }
                    guard valid else { continue }
                default: continue // Unrecognized/by-appointment dates stay unknown, never assumed closed.
                }
                intervals += dayIntervals; coverage.append(.init(start: start, end: end))
            }
            guard let first = coverage.first, let last = coverage.last else { continue }
            let merged = merge(intervals)
            output[place] = Hours(intervals: merged, verifiedFrom: first.start, verifiedUntil: last.end,
                                  verifiedDays: coverage, fetchedAt: fetchedAt)
        }
        return output
    }
    static func merge(_ intervals: [OpeningInterval]) -> [OpeningInterval] {
        var result: [OpeningInterval] = []
        for interval in intervals.sorted(by: { $0.start < $1.start }) {
            if let last = result.last, interval.start <= last.end { result[result.count - 1].end = max(last.end, interval.end) }
            else { result.append(interval) }
        }
        return result
    }
}

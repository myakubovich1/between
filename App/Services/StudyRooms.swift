import Foundation

/// Public, read-only LibCal search. Reservations are always completed on UF's own site.
struct StudyRoom: Identifiable, Codable, Sendable {
    var id: String
    var name: String
    var capacity: Int?
    var url: URL
    // UF's selected-time link is kept only in memory and deliberately excluded from Codable.
    var bookingURL: URL? = nil
    private enum CodingKeys: String, CodingKey { case id, name, capacity, url }
}
struct RoomAvailability: Codable, Sendable {
    var rooms: [StudyRoom]
    var total: Int
    var start: Date
    var end: Date
    var retrievedAt: Date
    var searchURL: URL
    func isCurrent(at now: Date) -> Bool { now >= retrievedAt && now.timeIntervalSince(retrievedAt) < 120 && end > now }
}
struct RoomLocation: Sendable {
    var lid: Int
    var gid: Int
    var reservationSlug: String
    static let all: [String: Self] = [
        "west": .init(lid: 4458, gid: 7520, reservationSlug: "studyLW"),
        "marston": .init(lid: 4316, gid: 7502, reservationSlug: "studyMSL"),
        "education": .init(lid: 4455, gid: 7509, reservationSlug: "studyEDU"),
        "health": .init(lid: 4913, gid: 8476, reservationSlug: "individualstudyHSCL")
    ]
}
actor StudyRoomService {
    typealias Fetch = @Sendable (URL, Int) async throws -> Data
    private let fetch: Fetch
    private var cache: [String: RoomAvailability] = [:]
    private var pending: [String: Task<RoomAvailability, Error>] = [:]
    init(fetch: @escaping Fetch = { try await UFHTTP.fetch($0, maxBytes: $1) }) { self.fetch = fetch }
    static func nextSlot(after date: Date) -> Date {
        // Epoch half hours also align to UF local half hours through DST transitions.
        Date(timeIntervalSince1970: ceil(date.timeIntervalSince1970 / 1800) * 1800)
    }
    static func searchURL(placeID: String, start: Date, minutes: Int, groupID: Int? = nil, capacity: Int = 0) throws -> URL {
        guard let location = RoomLocation.all[placeID], [30, 60, 90, 120].contains(minutes), (0...4).contains(capacity) else { throw URLError(.badURL) }
        let group = groupID ?? location.gid
        guard group == location.gid || (placeID == "health" && group == 9718) else { throw URLError(.badURL) }
        let endDate = start.addingTimeInterval(Double(minutes) * 60)
        let formatter = DateFormatter(); formatter.timeZone = TimeZone(identifier: "America/New_York")!; formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"; let date = formatter.string(from: start), endDay = formatter.string(from: endDate)
        formatter.dateFormat = "HH:mm"; let from = formatter.string(from: start), to = formatter.string(from: start.addingTimeInterval(Double(minutes) * 60))
        var url = URLComponents(string: "https://libcal.uflib.ufl.edu/r/search")!
        url.queryItems = ["m":"t", "lid":String(location.lid), "gid":String(group), "capacity":String(capacity), "date":date, "date-end":endDay, "start":from, "end":to].sorted { $0.key < $1.key }.map { .init(name: $0.key, value: $0.value) }
        return url.url!
    }
    func availability(placeID: String, start: Date, minutes: Int = 30, groupID: Int? = nil, capacity: Int = 0, force: Bool = false) async throws -> RoomAvailability {
        let url = try Self.searchURL(placeID: placeID, start: start, minutes: minutes, groupID: groupID, capacity: capacity)
        let key = url.absoluteString
        if !force, let value = cache[key], value.isCurrent(at: Date()) { return value }
        if let task = pending[key] { return try await task.value }
        let fetch = fetch
        let task = Task {
            let data = try await fetch(url, 1_500_000)
            return try LibCalRoomParser.parse(data, start: start, end: start.addingTimeInterval(Double(minutes) * 60), retrievedAt: Date(), searchURL: url)
        }
        pending[key] = task
        defer { pending[key] = nil }
        let value = try await task.value
        cache = cache.filter { Date().timeIntervalSince($0.value.retrievedAt) < 120 }
        cache[key] = value
        return value
    }
}

enum LibCalRoomParser {
    static func matches(_ pattern: String, _ text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (0..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : ns.substring(with: match.range(at: $0)) }
        }
    }
    static func text(_ html: String) -> String {
        var output = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for (entity, value) in ["&amp;":"&", "&quot;":"\"", "&#039;":"'", "&#39;":"'", "&apos;":"'", "&nbsp;":" ", "&ndash;":"–", "&mdash;":"—", "&lt;":"<", "&gt;":">"] { output = output.replacingOccurrences(of: entity, with: value) }
        for match in matches("&#(x[0-9a-f]+|[0-9]+);", output) {
            let code = match[1].lowercased(); let number = code.hasPrefix("x") ? UInt32(code.dropFirst(), radix: 16) : UInt32(code)
            if let number, let scalar = UnicodeScalar(number) { output = output.replacingOccurrences(of: match[0], with: String(scalar)) }
        }
        return output.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func parse(_ data: Data, start: Date, end: Date, retrievedAt: Date, searchURL: URL) throws -> RoomAvailability {
        guard let html = String(data: data, encoding: .utf8), html.contains("s-lc-eq-search-results") else { throw URLError(.cannotParseResponse) }
        let resultSection = html.components(separatedBy: "id=\"s-lc-eq-search-results\"").dropFirst().joined().components(separatedBy: "id=\"s-lc-eq-search-other-results\"").first ?? ""
        var rooms: [StudyRoom] = []
        for block in resultSection.components(separatedBy: "class=\"media s-lc-booking-suggestion\"").dropFirst() {
            guard let heading = matches("<h3[^>]*>(.*?)</h3>", block).first,
                  let link = matches("href=[\"'](/space/([0-9]+)[^\"']*)[\"']", heading[1]).first else { continue }
            let name = text(heading[1]); guard !name.isEmpty else { continue }
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "America/New_York")!; formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"; formatter.isLenient = false
            guard let rawStart = matches("name=\"start\" value=\"([^\"]+)\"", block).first,
                  let rawEnd = matches("name=\"end\" value=\"([^\"]+)\"", block).first,
                  let actualStart = formatter.date(from: rawStart[1]), let actualEnd = formatter.date(from: rawEnd[1]),
                  abs(actualStart.timeIntervalSince(start)) < 1, abs(actualEnd.timeIntervalSince(end)) < 1 else { throw URLError(.cannotParseResponse) }
            let capacity = matches("title=\"The capacity of this space\"[^>]*>(.*?)</span>", block).first.flatMap { Int(text($0[1])) }
            // Retain the stable detail URL; the exact-time link is ephemeral and only opens in the browser.
            let room = StudyRoom(id: link[2], name: name, capacity: capacity,
                                 url: URL(string: "https://libcal.uflib.ufl.edu/space/" + link[2])!,
                                 bookingURL: UFBookingPortal.roomURL(href: link[1], roomID: link[2], start: start, end: end))
            if !rooms.contains(where: { $0.id == room.id }) { rooms.append(room) }
        }
        let total = matches("Showing\\s+(\\d+)\\s+match", resultSection).first.flatMap { Int($0[1]) }
        let plain = text(resultSection).lowercased()
        let explicitlyEmpty = plain.contains("no spaces") || plain.contains("no matches") || plain.contains("no available") || plain.contains("no results") || plain.contains("no items")
        guard let count = total ?? (explicitlyEmpty ? 0 : nil), count >= rooms.count, count == 0 || !rooms.isEmpty else { throw URLError(.cannotParseResponse) }
        return .init(rooms: rooms, total: count, start: start, end: end, retrievedAt: retrievedAt, searchURL: searchURL)
    }
}

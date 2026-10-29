import Foundation

struct Coordinate: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
}

enum Access: String, Codable, CaseIterable, Sendable {
    case unrestricted, uf, graduate, unknown
    var label: String { switch self {
    case .unrestricted: "Open to visitors"
    case .uf: "UF access required"
    case .graduate: "Graduate students only"
    case .unknown: "Check entry requirements"
    }}
    func allows(_ eligibility: Access) -> Bool {
        self == .unrestricted || (self == .uf && [.uf, .graduate].contains(eligibility)) || (self == .graduate && eligibility == .graduate)
    }
}
struct Amenities: Codable, Hashable, Sendable {
    var outlets: Bool?
    var wifi: Bool?
    var group: Bool?
}
struct Zone: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var quiet: Bool
    var access: Access
}
struct Source: Codable, Hashable, Sendable {
    var url: URL
    var checked: String
    var facts: String
}
struct OpeningInterval: Codable, Hashable, Sendable {
    var start: Date
    var end: Date
}
struct Hours: Codable, Hashable, Sendable {
    var intervals: [OpeningInterval]
    /// Covers dates for which even an empty intervals array means a verified closure.
    var verifiedFrom: Date
    var verifiedUntil: Date
    /// Explicit valid days prevent malformed or by-appointment entries becoming assumed closures.
    var verifiedDays: [OpeningInterval]? = nil
    var fetchedAt: Date? = nil
    func closing(at arrival: Date) -> HoursState {
        if let fetchedAt, arrival.timeIntervalSince(fetchedAt) > 24 * 3600 { return .unknown }
        if let verifiedDays, !verifiedDays.contains(where: { $0.start <= arrival && arrival < $0.end }) { return .unknown }
        guard arrival >= verifiedFrom && arrival < verifiedUntil else { return .unknown }
        guard let interval = intervals.first(where: { $0.start <= arrival && arrival < $0.end }) else { return .closed }
        return .open(until: interval.end)
    }
}
enum HoursState: Equatable, Sendable {
    case unknown, closed, open(until: Date)
}
struct Place: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var shortName: String
    var aliases: [String]
    var category: String
    var address: String
    var coordinate: Coordinate?
    var coordinateNote: String
    var access: Access
    var quiet: Bool
    var amenities: Amenities
    var zones: [Zone]
    var hours: Hours?
    var hoursURL: URL
    var reservationURL: URL?
    var note: String
    var sources: [Source]
    func hoursLabel(at date: Date) -> String {
        switch hours?.closing(at: date) ?? .unknown {
        case .unknown: "Hours not confirmed"
        case .closed: "Closed now"
        case .open(let end): "Open until " + (CampusClock.sameDay(date, end) ? "" : CampusClock.dayLabel(end) + " ") + CampusClock.timeLabel(end)
        }
    }
    func nextOpeningLabel(at now: Date) -> String {
        guard let hours, let fetched = hours.fetchedAt, now.timeIntervalSince(fetched) < 86400,
              let next = hours.intervals.first(where: { $0.start > now }) else { return "Check the published schedule" }
        return "Opens " + (CampusClock.sameDay(now, next.start) ? "" : CampusClock.dayLabel(next.start) + " ") + CampusClock.timeLabel(next.start)
    }
    var symbol: String { category == "library" ? "books.vertical" : "building.2" }
    func matches(_ query: String) -> Bool {
        query.isEmpty || ([name, shortName] + aliases).contains { $0.localizedStandardContains(query) }
    }
}
enum Seat: Int, Codable, CaseIterable, Sendable {
    case plenty, some, almostFull, full
    var label: String { switch self {
    case .plenty: "Plenty of seats"
    case .some: "Some seats"
    case .almostFull: "Almost full"
    case .full: "Full"
    }}
    var symbol: String { switch self {
    case .plenty: "chair.lounge.fill"
    case .some: "chair.fill"
    case .almostFull: "person.2.fill"
    case .full: "person.3.fill"
    }}
}
enum Noise: Int, Codable, CaseIterable, Sendable {
    case silent, low, lively
    var label: String { switch self { case .silent: "Silent"; case .low: "Low conversation"; case .lively: "Lively" } }
}
struct CommunityObservation: Codable, Identifiable, Sendable {
    var id: String
    /// Private/demo domain input only. This model is never fetched by public clients.
    var author: String
    var placeID: String
    var zoneID: String?
    var seat: Seat
    var noise: Noise?
    var acceptedAt: Date
    var nearby: Bool
    var removed = false
    var suspended = false
}
struct Evidence: Codable, Sendable {
    var placeID: String
    var zoneID: String?
    var seat: Seat?
    var noise: Noise?
    var differs: Bool
    var reporters: Int
    var newestAt: Date?
    var evaluatedAt: Date
    var expiresAt: Date?
    var references: [String]
    static func empty(place: String, zone: String? = nil, now: Date) -> Self {
        .init(placeID: place, zoneID: zone, differs: false, reporters: 0, evaluatedAt: now, references: [])
    }
    func current(at now: Date) -> Bool { reporters > 0 && expiresAt.map { now < $0 } == true }
    func label(at now: Date) -> String {
        guard current(at: now) else { return reporters > 0 ? "Reports have expired" : "No recent reports" }
        return differs ? "Reports differ" : seat?.label ?? "No recent reports"
    }
}
struct OfficialOccupancy: Codable, Sendable {
    var sourceName: String
    var count: Int?
    var percent: Double?
    var observedAt: Date?
    var retrievedAt: Date
    func hasRecentRetrieval(at now: Date, limit: TimeInterval = 120) -> Bool {
        let age = now.timeIntervalSince(retrievedAt)
        return age >= 0 && age < limit
    }
    func isFresh(at now: Date, limit: TimeInterval = 300) -> Bool {
        observedAt.map { now.timeIntervalSince($0) >= 0 && now.timeIntervalSince($0) < limit } ?? false
    }
}
protocol OfficialOccupancyProvider: Sendable {
    func observation(for placeID: String) async throws -> OfficialOccupancy?
}
struct UnavailableOccupancyProvider: OfficialOccupancyProvider {
    func observation(for placeID: String) async throws -> OfficialOccupancy? { nil }
}
struct Filters: Codable, Equatable, Sendable {
    var openNow = false
    var quiet = false
    var outlets = false
    var wifi = false
    var group = false
    var confirmedAccess = false
    var preferredNoise: Noise?
    var maxWalk = 30
    var eligibility: Access = .uf
    var minimumStudy = 15
    var reservableRooms: Bool? = nil
    var count: Int { [openNow, quiet, outlets, wifi, group, confirmedAccess, preferredNoise != nil, maxWalk < 30, eligibility != .uf, minimumStudy != 15, reservableRooms == true].filter { $0 }.count }
}
struct CampusDestination: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var coordinate: Coordinate
    var address: String?
    var abbreviation: String? = nil
    var sourceURL: URL? = nil
}
struct TimePlan: Codable, Equatable, Sendable {
    var available = 45
    var buffer = 5
    var nextID: String?
    var nextDestination: CampusDestination? = nil
    var endsAt: Date? = nil
    func deadline(at now: Date) -> Date { endsAt ?? now.addingTimeInterval(Double(available) * 60) }
    func remainingMinutes(at now: Date) -> Int { max(0, min(available, Int(ceil(deadline(at: now).timeIntervalSince(now) / 60)))) }
    var hasNextDestination: Bool { nextID != nil || nextDestination != nil }
}
struct Journey: Sendable {
    var to: Double
    var onward: Double
    var estimated: Bool
}
struct Recommendation: Identifiable, Sendable {
    var id: String { place.id }
    var place: Place
    var journey: Journey
    var studyMinutes: Int
    var score: Double
    var uncertain: Bool
    var explanation: String
}
struct MyReport: Codable, Identifiable, Sendable {
    var id: String
    var placeID: String
    var zoneID: String?
    var seat: Seat
    var acceptedAt: Date
}

enum CampusClock {
    static func sameDay(_ a: Date, _ b: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar.isDate(a, inSameDayAs: b)
    }
    static func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.timeZone = TimeZone(identifier: "America/New_York"); formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    static func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

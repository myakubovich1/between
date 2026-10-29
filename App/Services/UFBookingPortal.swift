import Foundation

/// Read-only links into UF's own LibCal. Booking and identity stay with UF in the user's browser.
enum UFBookingPortal {
    static let allSpaces = URL(string: "https://libcal.uflib.ufl.edu/allspaces")!
    static let policies = URL(string: "https://uflib.ufl.edu/using-the-libraries/studyareas/")!
    struct Destination: Identifiable, Sendable {
        let id: String
        let name: String
        let detail: String
        let url: URL
    }
    static let destinations: [Destination] = [
        .init(id: "west", name: "Library West", detail: "Study rooms and individual carrels", url: URL(string: "https://libcal.uflib.ufl.edu/reserve/studyLW")!),
        .init(id: "marston", name: "Marston", detail: "Study rooms", url: URL(string: "https://libcal.uflib.ufl.edu/reserve/studyMSL")!),
        .init(id: "education", name: "Education", detail: "Study rooms", url: URL(string: "https://libcal.uflib.ufl.edu/reserve/studyEDU")!),
        .init(id: "health", name: "Health Science", detail: "Individual study rooms", url: URL(string: "https://libcal.uflib.ufl.edu/reserve/individualstudyHSCL")!),
        .init(id: "health-group", name: "Health Science · Groups", detail: "Group study rooms", url: URL(string: "https://libcal.uflib.ufl.edu/r/search?lid=4913&gid=9718")!),
        .init(id: "west-graduate", name: "West · Graduate floor", detail: "Currently enrolled UF graduate students only", url: URL(string: "https://libcal.uflib.ufl.edu/reserve/gradstudyLW")!)
    ]
    static func isOfficial(_ url: URL) -> Bool {
        url.scheme == "https" && ["libcal.uflib.ufl.edu", "ufl.libcal.com"].contains(url.host?.lowercased() ?? "") &&
        url.user == nil && url.password == nil && (url.port == nil || url.port == 443)
    }
    /// Preserve only UF-generated links for the exact returned room and interval, never manufacture a signature.
    static func roomURL(href: String, roomID: String, start: Date, end: Date) -> URL? {
        guard !roomID.isEmpty, roomID.allSatisfy(\.isNumber),
              let url = URL(string: href.replacingOccurrences(of: "&amp;", with: "&"), relativeTo: allSpaces)?.absoluteURL,
              isOfficial(url), url.path == "/space/" + roomID, url.fragment == nil,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              items.count == 3, Set(items.map(\.name)) == ["start", "end", "checksum"] else { return nil }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")!; formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"; formatter.isLenient = false
        guard let from = items.first(where: { $0.name == "start" })?.value.flatMap(formatter.date(from:)),
              let to = items.first(where: { $0.name == "end" })?.value.flatMap(formatter.date(from:)),
              abs(from.timeIntervalSince(start)) < 1, abs(to.timeIntervalSince(end)) < 1,
              let signature = items.first(where: { $0.name == "checksum" })?.value,
              signature.range(of: "^[a-fA-F0-9]{16,64}$", options: .regularExpression) != nil else { return nil }
        return url
    }
    static func destination(for room: StudyRoom, availability: RoomAvailability, at now: Date, refreshFailed: Bool = false) -> URL {
        if !refreshFailed, availability.isCurrent(at: now), let href = room.bookingURL,
           availability.rooms.contains(where: { $0.id == room.id }),
           let verified = roomURL(href: href.absoluteString, roomID: room.id, start: availability.start, end: availability.end) { return verified }
        // An old / unsupported room link returns to the same selected-time UF search, not a stale checkout.
        return availability.searchURL
    }
}

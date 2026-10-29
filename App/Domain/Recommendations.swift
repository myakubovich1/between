import Foundation

enum RecommendationEngine {
    static func studyMinutes(now: Date, plan: TimePlan, journey: Journey, hours: HoursState) -> Int {
        let arrival = now.addingTimeInterval(journey.to * 60)
        var finish = plan.deadline(at: now).addingTimeInterval(-Double(plan.buffer) * 60 - journey.onward * 60)
        switch hours {
        case .closed: return 0
        case .open(let closing): finish = min(finish, closing)
        case .unknown: break
        }
        return max(0, Int(floor(finish.timeIntervalSince(arrival) / 60)))
    }
    static func isQuiet(_ place: Place, filters: Filters) -> Bool {
        place.quiet || place.zones.contains { $0.quiet && ($0.access.allows(filters.eligibility) || ($0.access == .unknown && !filters.confirmedAccess)) }
    }
    static func matchesNeeds(_ place: Place, filters: Filters) -> Bool {
        (!filters.quiet || isQuiet(place, filters: filters)) &&
        (!filters.outlets || place.amenities.outlets == true) &&
        (!filters.wifi || place.amenities.wifi == true) &&
        (!filters.group || place.amenities.group == true) &&
        (filters.reservableRooms != true || place.reservationURL != nil) &&
        (!filters.confirmedAccess || place.access != .unknown) &&
        (place.access == .unknown || place.access.allows(filters.eligibility))
    }
    static func recommendations(places: [Place], journeys: [String: Journey], evidence: [String: Evidence], filters: Filters, plan: TimePlan, now: Date) -> [Recommendation] {
        places.compactMap { place in
            guard let journey = journeys[place.id], journey.to <= Double(filters.maxWalk) else { return nil }
            // A quiet requirement can match an eligible verified quiet zone without inventing current noise.
            let quiet = isQuiet(place, filters: filters)
            guard matchesNeeds(place, filters: filters) else { return nil }
            let accessUnknown = place.access == .unknown
            let hours = place.hours?.closing(at: now.addingTimeInterval(journey.to * 60)) ?? .unknown
            if case .closed = hours { return nil }
            if filters.openNow {
                guard case .open = place.hours?.closing(at: now) ?? .unknown else { return nil }
                guard case .open = hours else { return nil }
            }
            let minutes = studyMinutes(now: now, plan: plan, journey: journey, hours: hours)
            guard minutes >= filters.minimumStudy else { return nil }
            let report = evidence[place.id]
            let current = report?.current(at: now) == true
            let seatFit = current && report?.differs == false ? 1 - Double(report?.seat?.rawValue ?? 3) / 3 : 0
            let freshness = current ? max(0, 1 - now.timeIntervalSince(report?.newestAt ?? .distantPast) / 1800) : 0
            let baseFit = (quiet ? 0.6 : 0) + (place.amenities.outlets == true ? 0.2 : 0) + (place.amenities.wifi == true ? 0.2 : 0)
            let noiseFit: Double = if let preference = filters.preferredNoise, current, let sound = report?.noise { 1 - Double(abs(preference.rawValue - sound.rawValue)) / 2 } else { 0 }
            let fit = filters.preferredNoise == nil ? baseFit : baseFit * 0.5 + noiseFit * 0.5
            let score = 0.30 * fit + 0.25 * min(1, Double(minutes) / Double(max(1, plan.available))) + 0.20 * seatFit + 0.15 * max(0, 1 - (journey.to + journey.onward) / 60) + 0.10 * freshness
            let uncertain = hours == .unknown || accessUnknown
            return Recommendation(place: place, journey: journey, studyMinutes: minutes, score: score, uncertain: uncertain, explanation: quiet ? "A designated quiet space for a little focus." : "A place to make the most of your gap.")
        }.sorted { lhs, rhs in
            if lhs.uncertain != rhs.uncertain { return !lhs.uncertain }
            return lhs.score == rhs.score ? lhs.id < rhs.id : lhs.score > rhs.score
        }
    }
}

/// Demo and domain-test implementation; live aggregates are always computed on the server.
enum Aggregator {
    static func aggregate(_ reports: [CommunityObservation], place: String, zone: String? = nil, now: Date, blocked: Set<String> = []) -> Evidence {
        let valid = reports.filter { $0.placeID == place && $0.zoneID == zone && !$0.suspended && !blocked.contains($0.author) && now.timeIntervalSince($0.acceptedAt) >= 0 && now.timeIntervalSince($0.acceptedAt) < 1800 }
        var latest: [String: CommunityObservation] = [:]
        for report in valid {
            if let old = latest[report.author], old.acceptedAt > report.acceptedAt || (old.acceptedAt == report.acceptedAt && old.id > report.id) { continue }
            latest[report.author] = report
        }
        let unique = latest.values.filter { !$0.removed }
        guard !unique.isEmpty else { return .empty(place: place, zone: zone, now: now) }
        func weight(_ report: CommunityObservation) -> Double { (report.nearby ? 1 : 0.5) * pow(2, -now.timeIntervalSince(report.acceptedAt) / 600) }
        let total = unique.reduce(0) { $0 + weight($1) }
        let low = unique.filter { $0.seat.rawValue < 2 }.reduce(0) { $0 + weight($1) }
        let differs = unique.count >= 2 && low / total >= 0.30 && (total - low) / total >= 0.30
        func median(_ values: [(Int, Double)]) -> Int? {
            let sum = values.reduce(0) { $0 + $1.1 }
            guard sum > 0 else { return nil }
            var cumulative = 0.0
            // Exact ties select the lower ordinal; opposition is independently surfaced.
            for (value, w) in values.sorted(by: { $0.0 < $1.0 }) {
                cumulative += w
                if cumulative + 1e-12 >= sum / 2 { return value }
            }
            return nil
        }
        let seat = median(unique.map { ($0.seat.rawValue, weight($0)) }).flatMap(Seat.init)
        let noise = median(unique.compactMap { r in r.noise.map { ($0.rawValue, weight(r)) } }).flatMap(Noise.init)
        return Evidence(placeID: place, zoneID: zone, seat: seat, noise: noise, differs: differs, reporters: unique.count, newestAt: unique.map(\.acceptedAt).max(), evaluatedAt: now, expiresAt: unique.map { $0.acceptedAt.addingTimeInterval(1800) }.min(), references: unique.sorted { $0.id < $1.id }.map(\.id))
    }
}

/// Monotonic request ticket guards state against completion in a different order.
struct RequestGeneration: Sendable {
    private(set) var value = 0
    mutating func next() -> Int { value += 1; return value }
    func accepts(_ ticket: Int) -> Bool { ticket == value }
}

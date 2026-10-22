import Foundation
import Testing
@testable import Between

struct DomainTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func place(_ id: String = "p", hours: Hours? = nil, access: Access = .unrestricted, outlets: Bool? = nil) -> Place {
        Place(id: id, name: "A very long library name for testing", shortName: "Library", aliases: ["MSL"], category: "library", address: "Campus", coordinate: .init(latitude: 29, longitude: -82), coordinateNote: "Test", access: access, quiet: true, amenities: .init(outlets: outlets, wifi: nil, group: nil), zones: [], hours: hours, hoursURL: URL(string:"https://ufl.edu")!, note: "", sources: [])
    }
    func observation(_ id: String, _ author: String, _ seat: Seat, age: TimeInterval = 0, nearby: Bool = true, zone: String? = nil, noise: Noise? = nil) -> CommunityObservation {
        .init(id: id, author: author, placeID: "p", zoneID: zone, seat: seat, noise: noise, acceptedAt: now.addingTimeInterval(-age), nearby: nearby)
    }
    @Test func fortyFiveMinutePlan() {
        let plan = TimePlan(available: 45, buffer: 5, nextID: "next")
        #expect(RecommendationEngine.studyMinutes(now: now, plan: plan, journey: .init(to: 6, onward: 7, estimated: false), hours: .open(until: now.addingTimeInterval(3600))) == 27)
        #expect(RecommendationEngine.studyMinutes(now: now, plan: plan, journey: .init(to: 40, onward: 7, estimated: false), hours: .unknown) == 0)
    }
    @Test func closingDuringPlanAndBeforeArrival() {
        let hours = Hours(intervals: [.init(start: now.addingTimeInterval(-300), end: now.addingTimeInterval(1200))], verifiedFrom: now.addingTimeInterval(-600), verifiedUntil: now.addingTimeInterval(7200))
        #expect(RecommendationEngine.studyMinutes(now: now, plan: .init(), journey: .init(to: 6, onward: 0, estimated: false), hours: hours.closing(at: now.addingTimeInterval(360))) == 14)
        #expect(hours.closing(at: now.addingTimeInterval(1200)) == .closed)
        #expect(hours.closing(at: now.addingTimeInterval(8000)) == .unknown)
    }
    @Test func overnightHolidayAndDST() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int) throws -> Date { try #require(calendar.date(from: DateComponents(year:y,month:m,day:d,hour:h))) }
        let start = try date(2026,10,31,22), end = try date(2026,11,1,3)
        let hours = Hours(intervals: [.init(start:start,end:end)], verifiedFrom:start, verifiedUntil: try date(2026,11,3,0))
        #expect(end.timeIntervalSince(start) == 6*3600) // Fall-back overnight includes the repeated hour.
        #expect(hours.closing(at: try date(2026,11,1,2)) == .open(until:end))
        #expect(hours.closing(at: try date(2026,11,2,12)) == .closed) // Date-specific holiday override.
        #expect(hours.closing(at: try date(2026,11,4,12)) == .unknown)
    }
    @Test func hardRequirementsAndUnknownAccess() {
        var filters = Filters();filters.outlets = true
        let journeys: [String:Journey] = ["p":.init(to:6,onward:0,estimated:true)]
        #expect(RecommendationEngine.recommendations(places:[place()],journeys:journeys,evidence:[:],filters:filters,plan:.init(),now:now).isEmpty)
        #expect(RecommendationEngine.recommendations(places:[place(access:.graduate,outlets:true)],journeys:journeys,evidence:[:],filters:filters,plan:.init(),now:now).isEmpty)
        let uncertain = RecommendationEngine.recommendations(places:[place(access:.unknown,outlets:true)],journeys:journeys,evidence:[:],filters:filters,plan:.init(),now:now)
        #expect(uncertain.first?.uncertain == true)
        filters.openNow = true
        #expect(RecommendationEngine.recommendations(places:[place(outlets:true)],journeys:journeys,evidence:[:],filters:filters,plan:.init(),now:now).isEmpty)
    }
    @Test func reportsExpireWithoutPush() {
        let reports = [observation("a","u",.some,age:1799)]
        let status = Aggregator.aggregate(reports,place:"p",now:now)
        #expect(status.current(at:now))
        #expect(!status.current(at:now.addingTimeInterval(1)))
        #expect(Aggregator.aggregate(reports,place:"p",now:now.addingTimeInterval(1)).reporters == 0)
    }
    @Test func repeatReportsOnlyOneIndependentContributor() {
        let result = Aggregator.aggregate([observation("a","u",.full,age:400),observation("b","u",.plenty)],place:"p",now:now)
        #expect(result.reporters == 1);#expect(result.seat == .plenty)
    }
    @Test func decayAndPresenceWeights() {
        let result = Aggregator.aggregate([observation("old","a",.full,age:1200),observation("new","b",.some,nearby:false)],place:"p",now:now)
        #expect(result.seat == .some);#expect(result.differs)
    }
    @Test func exactMedianTieAndOpposition() {
        let tied = Aggregator.aggregate([observation("a","a",.plenty),observation("b","b",.some)],place:"p",now:now)
        #expect(tied.seat == .plenty);#expect(!tied.differs)
        let opposed = Aggregator.aggregate([observation("a","a",.plenty),observation("b","b",.full)],place:"p",now:now)
        #expect(opposed.differs);#expect(opposed.label(at:now) == "Reports differ")
    }
    @Test func scopeNoiseBlocksAndModeration() {
        var removed = observation("removed","c",.full);removed.removed = true
        var suspended = observation("suspended","d",.full);suspended.suspended = true
        let reports = [observation("a","a",.plenty),observation("b","b",.full,zone:"floor",noise:.lively),removed,suspended]
        let building = Aggregator.aggregate(reports,place:"p",now:now)
        #expect(building.noise == nil);#expect(building.reporters == 1)
        #expect(Aggregator.aggregate(reports,place:"p",zone:"floor",now:now).noise == .lively)
        #expect(Aggregator.aggregate(reports,place:"p",now:now,blocked:["a"]).reporters == 0)
    }
    @Test func removedLatestDoesNotResurrectOlderInfluence() {
        var removed = observation("latest","a",.full); removed.removed = true
        let reports = [observation("old","a",.plenty,age:400),removed]
        #expect(Aggregator.aggregate(reports,place:"p",now:now).reporters == 0)
    }
    @Test func explicitConfirmedAccessExcludesUnknown() {
        var filter = Filters(); filter.confirmedAccess = true
        #expect(RecommendationEngine.recommendations(places:[place(access:.unknown)],journeys:["p":.init(to:6,onward:0,estimated:true)],evidence:[:],filters:filter,plan:.init(),now:now).isEmpty)
    }
    @Test func officialFreshnessUsesObservationTime() {
        var official = OfficialOccupancy(sourceName:"Official",count:12,percent:nil,observedAt:now.addingTimeInterval(-600),retrievedAt:now)
        #expect(!official.isFresh(at:now));official.retrievedAt = now.addingTimeInterval(300);#expect(!official.isFresh(at:now.addingTimeInterval(300)))
        official.observedAt = nil;#expect(!official.isFresh(at:now))
        #expect(official.count == 12)
    }
    @Test func staleResponsesCannotReplaceNewSearch() {
        var generation = RequestGeneration();let first=generation.next();let second=generation.next()
        #expect(!generation.accepts(first));#expect(generation.accepts(second))
    }
    @Test func aliasesAndNoNegativeTimeCandidates() {
        let p = place();#expect(p.matches("msl"));#expect(p.matches("library"));#expect(!p.matches("pizza"))
        #expect(RecommendationEngine.recommendations(places:[p],journeys:["p":.init(to:29,onward:20,estimated:true)],evidence:[:],filters:.init(),plan:.init(),now:now).isEmpty)
    }
}

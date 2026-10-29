import Foundation
import Testing
@testable import Between

private final class LiveFixtureBundle: NSObject {}
private func fixture(_ name: String) throws -> Data {
    let parts = name.split(separator: ".", maxSplits: 1)
    let url = try #require(Bundle(for: LiveFixtureBundle.self).url(forResource: String(parts[0]), withExtension: String(parts[1])))
    return try Data(contentsOf: url)
}
private actor FixtureUFHTTP {
    let manifest: Data
    var calls: [String: Int] = [:]
    var failing: Set<String> = []
    init(manifest: Data) { self.manifest = manifest }
    func setFailures(_ paths: Set<String>) { failing = paths }
    func count(_ path: String) -> Int { calls[path, default: 0] }
    func fetch(_ url: URL, _ max: Int) async throws -> Data {
        calls[url.path, default: 0] += 1
        try await Task.sleep(for: .milliseconds(5))
        if failing.contains(url.path) { throw URLError(.notConnectedToInternet) }
        return url.host == "www.uflib.ufl.edu" ? manifest : Data("456".utf8)
    }
}
struct LiveDataTests {
    private let now = ISO8601DateFormatter().date(from: "2026-10-28T18:00:00Z")!
    @Test func officialPageMapsAllBuildingsAndAreas() throws {
        let ids = UFLibraryData.parseManifest(try fixture("uf-status-2026-10-28.html"))
        #expect(ids.count == 11)
        #expect(ids["west"] == "6be1325f")
        #expect(ids["marston-makerspace"] == "c90fca36")
        #expect(ids["smathers-grand"] == "476d11b2")
        #expect(UFLibraryData.parseManifest(Data("<html>error</html>".utf8)).isEmpty)
    }
    @Test func occupancyRequestsCoalesceAndFailedRefreshNeverReissuesOldValues() async throws {
        let http = FixtureUFHTTP(manifest: try fixture("uf-status-2026-10-28.html"))
        let service = UFLibraryData(fetch: { try await http.fetch($0, $1) })
        async let first = service.occupancy(at: now)
        async let second = service.occupancy(at: now)
        let (a,b) = await (first,second)
        #expect(a.observations.count == 11); #expect(b.observations.count == 11)
        #expect(await http.count(UFLibraryData.sourceURL.path) == 1)
        #expect(await http.count("/value/live/6be1325f") == 1)
        _ = await service.occupancy(at: now.addingTimeInterval(59))
        #expect(await http.count("/value/live/6be1325f") == 1)
        await http.setFailures(["/value/live/6be1325f"])
        let failed = await service.occupancy(at: now.addingTimeInterval(60), force: true)
        #expect(failed.failed == ["west"])
        #expect(failed.observations["west"] == nil)
        #expect(failed.observations.count == 10)
    }
    @Test func savedRetrievalIsDistinctFromSensorFreshness() {
        let value = OfficialOccupancy(sourceName: "UF", count: 0, observedAt: nil, retrievedAt: now)
        #expect(value.hasRecentRetrieval(at: now.addingTimeInterval(119)))
        #expect(!value.hasRecentRetrieval(at: now.addingTimeInterval(120)))
        #expect(!value.hasRecentRetrieval(at: now.addingTimeInterval(-1)))
        #expect(!value.isFresh(at: now))
        #expect(value.count == 0)
    }
    @Test func exactRoomMatchesHaveNamesCapacitiesAndOfficialURLs() throws {
        let url = try StudyRoomService.searchURL(placeID: "west", start: now, minutes: 30)
        let selectedStart = ISO8601DateFormatter().date(from: "2026-10-29T02:30:00Z")!
        let result = try LibCalRoomParser.parse(fixture("uf-rooms-west-2026-10-28.html"), start: selectedStart, end: selectedStart.addingTimeInterval(1800), retrievedAt: now, searchURL: url)
        #expect(throws: (any Error).self) { try LibCalRoomParser.parse(fixture("uf-rooms-west-2026-10-28.html"), start: selectedStart.addingTimeInterval(1800), end: selectedStart.addingTimeInterval(3600), retrievedAt: now, searchURL: url) }
        #expect(result.total == 6); #expect(result.rooms.count == 6)
        #expect(result.rooms.first?.name == "Individual Study Carrel G-208")
        #expect(result.rooms.first?.capacity == 1)
        #expect(result.rooms.allSatisfy { $0.url.host == "libcal.uflib.ufl.edu" && $0.url.query == nil })
        #expect(result.isCurrent(at: now.addingTimeInterval(60)))
        #expect(!result.isCurrent(at: now.addingTimeInterval(121)))
    }
    @Test func otherTimeSuggestionsNeverCountAsAvailableForSelectedTime() throws {
        let url = try StudyRoomService.searchURL(placeID: "education", start: now, minutes: 30)
        let result = try LibCalRoomParser.parse(fixture("uf-rooms-empty-2026-10-28.html"), start: now, end: now.addingTimeInterval(1800), retrievedAt: now, searchURL: url)
        #expect(result.total == 0); #expect(result.rooms.isEmpty)
    }
    @Test func invalidRoomResponsesStayUnavailable() throws {
        let url = try StudyRoomService.searchURL(placeID: "west", start: now, minutes: 30)
        for html in ["<html>Error</html>", "<div id=\"s-lc-eq-search-results\">Unknown layout</div>", "<div id=\"s-lc-eq-search-results\">Showing 6 matches</div>"] {
            #expect(throws: (any Error).self) { try LibCalRoomParser.parse(Data(html.utf8), start: now, end: now.addingTimeInterval(1800), retrievedAt: now, searchURL: url) }
        }
    }
    @Test func roomSearchUsesCampusTimeAndRejectsUnsupportedQueries() throws {
        let url = try StudyRoomService.searchURL(placeID: "marston", start: now, minutes: 60)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(items.contains(.init(name: "date", value: "2026-10-28")))
        #expect(items.contains(.init(name: "start", value: "14:00")))
        #expect(items.contains(.init(name: "end", value: "15:00")))
        #expect(throws: (any Error).self) { try StudyRoomService.searchURL(placeID: "made-up", start: now, minutes: 30) }
        #expect(throws: (any Error).self) { try StudyRoomService.searchURL(placeID: "west", start: now, minutes: 17) }
        let healthGroup = try StudyRoomService.searchURL(placeID: "health", start: now, minutes: 30, groupID: 9718)
        #expect(URLComponents(url: healthGroup, resolvingAgainstBaseURL: false)!.queryItems!.contains(.init(name: "gid", value: "9718")))
        #expect(throws: (any Error).self) { try StudyRoomService.searchURL(placeID: "west", start: now, minutes: 30, groupID: 9718) }
        let late = ISO8601DateFormatter().date(from: "2026-10-29T03:30:00Z")!
        let overnight = try StudyRoomService.searchURL(placeID: "west", start: late, minutes: 60)
        let overnightItems = URLComponents(url: overnight, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(overnightItems.contains(.init(name: "date-end", value: "2026-10-29")))
        #expect(overnightItems.contains(.init(name: "end", value: "00:30")))
        #expect(StudyRoomService.nextSlot(after: now.addingTimeInterval(1)) == now.addingTimeInterval(1800))
    }
}

struct StudentFlowTests {
    private let now = ISO8601DateFormatter().date(from: "2026-10-28T18:00:00Z")!
    @Test func aStudyGapCountsDownRatherThanRestartingOnRefresh() {
        let plan = TimePlan(available: 45, buffer: 5, endsAt: now.addingTimeInterval(45 * 60))
        let walk = Journey(to: 6, onward: 7, estimated: false)
        #expect(RecommendationEngine.studyMinutes(now: now, plan: plan, journey: walk, hours: .unknown) == 27)
        #expect(RecommendationEngine.studyMinutes(now: now.addingTimeInterval(600), plan: plan, journey: walk, hours: .unknown) == 17)
        #expect(plan.remainingMinutes(at: now.addingTimeInterval(600)) == 35)
        #expect(plan.remainingMinutes(at: now.addingTimeInterval(46 * 60)) == 0)
    }
    @Test func existingSavedPlansAndFiltersStillDecode() throws {
        let oldPlan = Data(#"{"available":45,"buffer":5}"#.utf8)
        let plan = try JSONDecoder().decode(TimePlan.self, from: oldPlan)
        #expect(plan.nextDestination == nil); #expect(plan.endsAt == nil)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(Filters())) as? [String: Any])
        json.removeValue(forKey: "reservableRooms")
        let filter = try JSONDecoder().decode(Filters.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(filter.reservableRooms == nil)
    }
    @Test func changedStudyMinimumAndRoomFilterAppearInActiveCount() {
        var filter = Filters(); #expect(filter.count == 0)
        filter.minimumStudy = 20; filter.reservableRooms = true
        #expect(filter.count == 2)
    }
    @MainActor @Test func clearingSearchCancelsAnOlderPendingQuery() async {
        let store = AppStore(config: .init(mode: .development, name: "Between", url: nil, key: ""))
        store.query = "no-such-library"; store.searchChanged(); store.clearSearch()
        try? await Task.sleep(for: .milliseconds(350))
        #expect(store.query.isEmpty); #expect(store.committedQuery.isEmpty)
        store.hasChosenOrigin = false; store.manualOrigin = nil; store.usesLocation = false
        #expect(store.origin == nil)
        store.committedQuery = "no-such-library"
        #expect(store.recommendations(using: Filters()).isEmpty)
        store.clearSearch(); store.plan.endsAt = nil
        store.chooseCurrentLocation()
        #expect(store.plan.endsAt != nil)
        store.plan.nextDestination = .init(id: "class", name: "Next class", coordinate: .init(latitude: 29.648, longitude: -82.344))
        #expect(store.nextName == "Next class"); #expect(store.plan.hasNextDestination)
    }
}

struct CampusDirectoryTests {
    @Test func officialCampusCoordinatesAndRoomSizeQueries() throws {
        let destinations = try CampusBuildingDirectory.parse(fixture("uf-campus-search-2026-10-29.json"))
        let turlington = try #require(destinations.first { $0.name == "Turlington Hall" })
        #expect(turlington.abbreviation == "TUR")
        #expect(CampusBuildingDirectory.matches(turlington, query: "Turlington TUR"))
        let reitz = CampusDestination(id: "reitz", name: "Reitz Student Union", coordinate: turlington.coordinate)
        #expect(CampusBuildingDirectory.matches(reitz, query: "Reitz Union"))
        #expect(!CampusBuildingDirectory.matches(reitz, query: "Norman"))
        #expect(turlington.coordinate == .init(latitude: 29.64921, longitude: -82.34407))
        #expect(turlington.sourceURL?.host == "campusmap.ufl.edu")
        let url = try StudyRoomService.searchURL(placeID: "west", start: Date(), minutes: 30, capacity: 2)
        #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.contains(.init(name: "capacity", value: "2")))
        #expect(throws: (any Error).self) { try StudyRoomService.searchURL(placeID: "west", start: Date(), minutes: 30, capacity: 5) }
    }
}

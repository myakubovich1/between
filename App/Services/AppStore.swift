import Foundation
import Observation
import MapKit
import Supabase
import UIKit
import OSLog

@MainActor @Observable
final class AppStore {
    let config: AppConfiguration
    var places: [Place] = []
    var evidence: [Evidence] = []
    var officialOccupancy: [String: OfficialOccupancy] = [:]
    var officialHoursFetchedAt: Date?
    var communityAvailable = false
    var officialIssue: String?
    let ufData = UFLibraryData()
    var favorites: Set<String> = []
    var filters = Filters()
    var plan = TimePlan()
    var query = ""
    var committedQuery = ""
    var originID = "marston"
    var usesLocation = false
    var journeys: [String: Journey] = [:]
    var signedIn = false
    var myReports: [MyReport] = []
    var error: String?
    var notice: String?
    var offline = false
    var refreshing = false
    var lastFetched: Date?
    var demoNoReports = false
    var demoOffline = false
    var demoOffset: TimeInterval = 0
    var demoReports: [CommunityObservation] = []
    var blocked: Set<String> = []
    var appleNonce: String?
    var displayTime = Date()
    let location = ForegroundLocation()
    let routes = WalkingRoutes()
    let cache: LocalCache
    let live: LiveService?
    private let logger = Logger(subsystem: "app.between.study", category: "state")
    private let launchedAt = Date()
    private var generation = RequestGeneration()
    private var didLoad = false
    private var routeTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var demoMine = "demo-local-contributor"
    private var demoReceipts: [String: Receipt] = [:]
    private var summaryGeneration = RequestGeneration()
    private var fixedDemoTime: Date { ISO8601DateFormatter().date(from: "2026-10-22T18:00:00Z") ?? launchedAt }
    var now: Date { config.isDemo ? fixedDemoTime.addingTimeInterval(displayTime.timeIntervalSince(launchedAt) + demoOffset) : displayTime }
    var origin: Coordinate? { usesLocation ? location.sample.map { .init(latitude: $0.latitude, longitude: $0.longitude) } : places.first { $0.id == originID }?.coordinate }
    var originName: String { usesLocation ? "My location" : places.first { $0.id == originID }?.shortName ?? "UF campus · manual origin" }
    var next: Place? { places.first { $0.id == plan.nextID } }
    var evidenceByPlace: [String: Evidence] { Dictionary(evidence.filter { $0.zoneID == nil }.map { ($0.placeID, $0) }, uniquingKeysWith: { _, newer in newer }) }
    var results: [Recommendation] {
        RecommendationEngine.recommendations(places: places.filter { $0.matches(committedQuery) }, journeys: journeys, evidence: evidenceByPlace, filters: filters, plan: plan, now: now)
    }
    init(config: AppConfiguration = .current) {
        self.config = config
        cache = LocalCache(mode: config.mode.rawValue)
        live = !config.isDemo && config.configured ? LiveService(config: config) : nil
        favorites = Set(UserDefaults.standard.stringArray(forKey: "between.\(config.mode.rawValue).favorites") ?? [])
        if let data = UserDefaults.standard.data(forKey: "between.filters"), let saved = try? JSONDecoder().decode(Filters.self, from: data) { filters = saved }
        if let data = UserDefaults.standard.data(forKey: "between.plan"), let saved = try? JSONDecoder().decode(TimePlan.self, from: data) { plan = saved }
        do {
            guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else { throw AppFailure.message("The campus catalog is missing. Reinstall the app.") }
            places = try JSONDecoder.between.decode([Place].self, from: Data(contentsOf: url))
        } catch { self.error = error.localizedDescription }
        if config.isDemo && ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            favorites = []; filters = Filters(); plan = TimePlan()
        }
        if config.isDemo {
            // Synthetic hours are only added inside the isolated Demo configuration.
            for i in places.indices {
                places[i].hours = Hours(intervals: [.init(start: fixedDemoTime.addingTimeInterval(-3600 * 6), end: fixedDemoTime.addingTimeInterval(3600 * 8))], verifiedFrom: fixedDemoTime.addingTimeInterval(-3600 * 6), verifiedUntil: fixedDemoTime.addingTimeInterval(3600 * 8))
            }
            seedDemo()
        }
        computeEstimatedJourneys()
    }
    func seedDemo() {
        demoReports = [
            .init(id: "demo-1", author: "fixture-a", placeID: "marston", seat: .some, noise: .low, acceptedAt: fixedDemoTime.addingTimeInterval(-240), nearby: true),
            .init(id: "demo-2", author: "fixture-b", placeID: "marston", seat: .some, noise: .low, acceptedAt: fixedDemoTime.addingTimeInterval(-420), nearby: false),
            .init(id: "demo-3", author: "fixture-c", placeID: "west", seat: .plenty, noise: .silent, acceptedAt: fixedDemoTime.addingTimeInterval(-360), nearby: true),
            .init(id: "demo-4", author: "fixture-d", placeID: "west", seat: .some, acceptedAt: fixedDemoTime.addingTimeInterval(-540), nearby: true),
            .init(id: "demo-5", author: "fixture-e", placeID: "smathers", seat: .almostFull, acceptedAt: fixedDemoTime.addingTimeInterval(-120), nearby: false),
            .init(id: "demo-6", author: "fixture-f", placeID: "marston", zoneID: "marston-4", seat: .plenty, noise: .silent, acceptedAt: fixedDemoTime.addingTimeInterval(-180), nearby: true)
        ]
        recalculateDemo()
    }
    func recalculateDemo() {
        guard config.isDemo else { return }
        evidence = places.flatMap { place in
            ([Optional<String>.none] + place.zones.map { Optional($0.id) }).map { zone in
                Aggregator.aggregate(demoNoReports ? [] : demoReports, place: place.id, zone: zone, now: now, blocked: blocked)
            }
        }
    }
    func runForeground() async {
        if !didLoad {
            didLoad = true
            do {
                if !(config.isDemo && ProcessInfo.processInfo.arguments.contains("-ui-testing")), let snapshot = try await cache.read() {
                    if config.isDemo, let reports = snapshot.demoReports { demoReports = reports; recalculateDemo() }
                    else { evidence = snapshot.evidence }
                    if !config.isDemo, let catalog = snapshot.catalog {
                        places = catalog
                        officialHoursFetchedAt = catalog.compactMap { $0.hours?.fetchedAt }.max()
                        officialOccupancy = snapshot.officialOccupancy ?? [:]
                    }
                    lastFetched = snapshot.fetchedAt
                }
            } catch { logger.error("Cache restore failed; bundled catalog retained."); notice = "Couldn’t restore cached conditions. Your saved places are safe; refresh to try again." }
        }
        signedIn = config.isDemo ? signedIn : live?.client.auth.currentSession != nil
        await checkAppleCredential()
        await refresh()
        scheduleRoutes()
        let realtimeTask = Task { @MainActor [weak self] in await self?.listenRealtime() }
        let clockTask = Task { @MainActor [weak self] in await self?.runExpiryClock() }
        let authTask = Task { @MainActor [weak self] in await self?.observeAuth() }
        defer { realtimeTask.cancel(); clockTask.cancel(); authTask.cancel() }
        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(60)) } catch { break }
            await refresh()
        }
        routeTask?.cancel()
        location.clear()
    }
    private func runExpiryClock() async {
        while !Task.isCancelled {
            let boundary = evidence.compactMap(\.expiresAt).filter { $0 > now }.min()
            let delay = min(60, max(0.1, boundary?.timeIntervalSince(now) ?? 60))
            do { try await Task.sleep(for: .seconds(delay + 0.02)) } catch { return }
            displayTime = Date()
            if let boundary, now >= boundary { await refresh() }
        }
    }
    private func observeAuth() async {
        guard let live else { return }
        for await (_, session) in live.client.auth.authStateChanges {
            if Task.isCancelled { return }
            signedIn = session != nil
            if session == nil { myReports = [] }
        }
    }
    private func listenRealtime() async {
        guard let live else { return }
        let channel = live.client.channel("uf-safe-status")
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "status_versions", filter: .eq("campus_id", value: "uf"))
        do {
            try await channel.subscribeWithError()
            for await _ in changes { if Task.isCancelled { break }; await refresh() }
        } catch { /* The bounded foreground refresh remains active. */ }
        await live.client.removeChannel(channel)
    }
    func refresh() async {
        displayTime = Date()
        let ticket = summaryGeneration.next()
        refreshing = true
        defer { if summaryGeneration.accepts(ticket) { refreshing = false } }
        do {
            if config.isDemo {
                if demoOffline { throw URLError(.notConnectedToInternet) }
                recalculateDemo()
            } else {
                // UF data works independently of the optional community-report backend.
                async let publishedCounts = ufData.occupancy()
                async let publishedSchedule = ufData.hours()
                var catalog = places
                var fetchedEvidence = evidence
                var backendAvailable = false
                if let live {
                    do {
                        let remote: [Place] = try await live.request("catalog")
                        fetchedEvidence = try await live.summaries()
                        catalog = remote.map { item in
                            var updated = item
                            updated.hours = places.first { $0.id == item.id }?.hours ?? item.hours
                            return updated
                        }; backendAvailable = true
                    } catch { /* Keep UF browsing available; community state is labeled separately. */ }
                }
                var hoursIssue: String?
                do {
                    let publishedHours = try await publishedSchedule
                    for i in catalog.indices {
                        // Keep source-specific cached hours if a catalog refresh has no schedule.
                        catalog[i].hours = publishedHours[catalog[i].id] ?? places.first { $0.id == catalog[i].id }?.hours
                    }
                } catch { hoursIssue = "UF hours couldn’t refresh. Check the official hours before visiting." }
                let counts = await publishedCounts
                guard summaryGeneration.accepts(ticket), !Task.isCancelled else { return }
                let catalogChanged = places != catalog
                places = catalog; evidence = fetchedEvidence
                officialOccupancy.merge(counts, uniquingKeysWith: { _, newer in newer })
                officialHoursFetchedAt = catalog.compactMap { $0.hours?.fetchedAt }.max()
                communityAvailable = backendAvailable
                let countsCurrent = counts.values.contains { Date().timeIntervalSince($0.retrievedAt) < 120 }
                officialIssue = hoursIssue ?? (countsCurrent ? nil : "UF building counts couldn’t refresh. Check the retrieval time before using a saved count.")
                if catalogChanged { scheduleRoutes() }
                if hoursIssue != nil && !countsCurrent { throw URLError(.notConnectedToInternet) }
            }
            guard summaryGeneration.accepts(ticket), !Task.isCancelled else { return }
            offline = false
            lastFetched = now
            try await cache.write(.init(evidence: evidence, fetchedAt: now, demoReports: config.isDemo ? demoReports : nil, catalog: config.isDemo ? nil : places, officialOccupancy: config.isDemo ? nil : officialOccupancy))
        } catch is CancellationError {} catch {
            guard summaryGeneration.accepts(ticket) else { return }
            offline = true
            if !config.isDemo { officialIssue = "UF data couldn’t refresh. Showing saved information where available." }
        }
    }
    func searchChanged() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self else { return }
            self.committedQuery = self.query
        }
    }
    func persistPreferences() {
        if let data = try? JSONEncoder().encode(filters) { UserDefaults.standard.set(data, forKey: "between.filters") }
        if let data = try? JSONEncoder().encode(plan) { UserDefaults.standard.set(data, forKey: "between.plan") }
        scheduleRoutes()
    }
    func toggleSave(_ place: Place) {
        if !favorites.insert(place.id).inserted { favorites.remove(place.id) }
        UserDefaults.standard.set(Array(favorites), forKey: "between.\(config.mode.rawValue).favorites")
    }
    func resetLocal() {
        favorites = []
        UserDefaults.standard.removeObject(forKey: "between.\(config.mode.rawValue).favorites")
        filters = Filters(); plan = TimePlan(); persistPreferences()
        Task { try? await cache.clear() }
    }
    func computeEstimatedJourneys() {
        let demoWalks: [String: Double] = ["marston": 6, "west": 8, "smathers": 9, "afa": 7, "education": 14, "health": 19, "newell": 5, "reitz": 12]
        journeys = Dictionary(places.compactMap { place in
            guard let destination = place.coordinate, let origin else { return nil }
            let to = config.isDemo ? demoWalks[place.id] ?? 10 : max(1, ceil(origin.distance(to: destination) / 75))
            let onward = next?.coordinate.map { config.isDemo ? 7 : max(1, ceil(destination.distance(to: $0) / 75)) } ?? 0
            return (place.id, Journey(to: to, onward: onward, estimated: true))
        }, uniquingKeysWith: { _, new in new })
    }
    func scheduleRoutes() {
        routeTask?.cancel()
        let ticket = generation.next()
        computeEstimatedJourneys()
        guard !config.isDemo, let origin else { return }
        let shortlist = results.prefix(4).map(\.place)
        let nextCoordinate = next?.coordinate
        routeTask = Task { [weak self] in
            guard let self else { return }
            for place in shortlist {
                guard !Task.isCancelled, let to = place.coordinate else { break }
                do {
                    let outbound = try await self.routes.route(from: origin, to: to)
                    var onward = 0.0
                    if let nextCoordinate { onward = try await self.routes.route(from: to, to: nextCoordinate).minutes }
                    guard self.generation.accepts(ticket), !Task.isCancelled else { return }
                    self.journeys[place.id] = Journey(to: ceil(outbound.minutes), onward: ceil(onward), estimated: false)
                } catch { if Task.isCancelled { return } }
            }
        }
    }
    func status(place: String, zone: String? = nil) -> Evidence {
        evidence.first { $0.placeID == place && $0.zoneID == zone } ?? .empty(place: place, zone: zone, now: now)
    }
    func submit(place: Place, zone: String?, seat: Seat, noise: Noise?, key: String, confirmedAt: Date, checkNearby: Bool) async throws {
        guard signedIn else { throw AppFailure.message("Sign in with Apple to contribute. Your choices are kept here.") }
        if config.isDemo {
            guard !demoOffline else { throw AppFailure.message("You’re offline. Your choices are kept. Reconfirm conditions when you reconnect.") }
            if demoReceipts[key] != nil { return }
            if let last = demoReports.filter({ $0.author == demoMine && $0.placeID == place.id && $0.zoneID == zone }).map(\.acceptedAt).max(), now.timeIntervalSince(last) < 300 {
                throw AppFailure.message("Try this place again in \(Int(ceil(300 - now.timeIntervalSince(last)))) seconds.")
            }
            let report = CommunityObservation(id: UUID().uuidString, author: demoMine, placeID: place.id, zoneID: zone, seat: seat, noise: noise, acceptedAt: now, nearby: false)
            demoReports.append(report)
            demoReceipts[key] = Receipt(id: report.id, acceptedAt: now, nearby: false)
            myReports.insert(MyReport(id: report.id, placeID: place.id, zoneID: zone, seat: seat, acceptedAt: now), at: 0)
            demoNoReports = false
            recalculateDemo()
            try await cache.write(.init(evidence: evidence, fetchedAt: now, demoReports: demoReports))
        } else {
            guard let live else { throw AppFailure.message("Connect a live backend before reporting.") }
            let _: Receipt = try await live.submit(.init(placeID: place.id, zoneID: zone, seat: seat, noise: noise, idempotencyKey: key, reconfirmedAt: confirmedAt, location: checkNearby ? location.sample : nil))
            await refresh()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    func flag(reference: String, block: Bool) async throws {
        if config.isDemo {
            guard let report = demoReports.first(where: { $0.id == reference }) else { return }
            if block { blocked.insert(report.author); recalculateDemo() }
            notice = block ? "Contributor muted in this demo." : "Flag recorded in this isolated demo."
        } else {
            guard let live, signedIn else { throw AppFailure.message("Sign in to flag or mute a contributor.") }
            struct Body: Encodable { var reference: String; var action: String }
            let _: EmptyResponse = try await live.request("feedback", method: "POST", body: JSONEncoder.between.encode(Body(reference: reference, action: block ? "block" : "flag")), authenticated: true)
            await refresh()
            notice = block ? "Contributor muted. Your results have been refreshed." : "Thanks. This report was flagged for review."
        }
    }
    func loadMyReports() async {
        guard let live, signedIn else { return }
        do { myReports = try await live.request("reports/mine", authenticated: true) } catch { self.error = error.localizedDescription }
    }
    func signOut() async {
        do {
            if let live { try await live.client.auth.signOut() }
            signedIn = false; myReports = []; evidence = []; try await cache.clear(); await refresh()
        } catch { self.error = error.localizedDescription }
    }
}
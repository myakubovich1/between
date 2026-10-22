import SwiftUI
import MapKit

struct PlaceDetailView: View {
    @Environment(AppStore.self) private var store
    @State private var zoneID: String?
    @State private var sheet: DetailSheet?
    @State private var route: MKRoute?
    @State private var routing = false
    @State private var routeError: String?
    @State private var showRoute = false
    @State private var directionTask: Task<Void, Never>?
    let place: Place
    enum DetailSheet: String, Identifiable { case report, evidence; var id: String { rawValue } }
    private var evidence: Evidence { store.status(place: place.id, zone: zoneID) }
    private var recommendation: Recommendation? { RecommendationEngine.recommendations(places: [place], journeys: store.journeys, evidence: store.evidenceByPlace, filters: Filters(minimumStudy: 0), plan: store.plan, now: store.now).first }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("UNIVERSITY OF FLORIDA", systemImage: "mappin.circle").font(.caption2.weight(.bold)).tracking(1.3).foregroundStyle(Color.forest)
                        Spacer()
                        Button { store.toggleSave(place) } label: { Image(systemName: store.favorites.contains(place.id) ? "bookmark.fill" : "bookmark").frame(width: 44, height: 44).background(Color.softForest, in: Circle()) }.accessibilityLabel(store.favorites.contains(place.id) ? "Unsave place" : "Save place").accessibilityIdentifier("detail-save")
                    }
                    Text(place.name).font(.system(.largeTitle, design: .rounded, weight: .bold)).tracking(-1)
                    Text(place.note).font(.subheadline).foregroundStyle(Color.metadata).fixedSize(horizontal: false, vertical: true)
                }
                if let coordinate = place.coordinate {
                    Map(initialPosition: .region(.init(center: coordinate.cl, span: .init(latitudeDelta: 0.003, longitudeDelta: 0.003)))) {
                        Marker(place.shortName, systemImage: place.symbol, coordinate: coordinate.cl).tint(Color.brandFill)
                        if let route { MapPolyline(route.polyline).stroke(Color.forest, lineWidth: 5) }
                    }.mapStyle(.standard(pointsOfInterest: .excludingAll)).frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 22))
                }
                if !place.zones.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Choose your space")
                        Picker("Floor or zone", selection: $zoneID) {
                            Text("Building-wide").tag(Optional<String>.none)
                            ForEach(place.zones) { zone in Text(zone.name + (zone.access == .graduate ? " · restricted" : "")).tag(Optional(zone.id)) }
                        }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading).padding(10).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("zone-picker")
                        if let zone = place.zones.first(where: { $0.id == zoneID }) {
                            Text(zone.access.label).font(.caption).foregroundStyle(Color.metadata)
                            if !zone.access.allows(store.filters.eligibility) { NoticeView(title: "This zone doesn’t match your entry eligibility.", symbol: "lock") }
                            if zone.quiet { Text("Designated quiet study · a venue policy, not a report of current noise.").font(.caption).foregroundStyle(Color.metadata) }
                        }
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Eyebrow(text: zoneID == nil ? "Building reports" : "This zone’s reports"); Spacer(); Image(systemName: "person.2.wave.2").foregroundStyle(Color.forest) }
                        StatusLabel(evidence: evidence, now: store.now)
                        if evidence.current(at: store.now), let noise = evidence.noise { Label(noise.label, systemImage: "waveform").font(.subheadline) }
                        else { Text("Current noise not reported").font(.subheadline).foregroundStyle(Color.metadata) }
                        EvidenceCaption(evidence: evidence, now: store.now)
                        Divider()
                        Button { sheet = .evidence } label: { HStack { Text("Where this comes from"); Spacer(); Image(systemName: "chevron.right") }.font(.subheadline).frame(minHeight: 44) }.accessibilityIdentifier("evidence")
                    }
                }
                if let recommendation {
                    Surface {
                        VStack(alignment: .leading, spacing: 14) {
                            Eyebrow(text: "Your \(store.plan.available)-minute gap")
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(recommendation.studyMinutes)").font(.system(size: 48, weight: .semibold, design: .rounded)).foregroundStyle(Color.forest)
                                Text("minutes to study").font(.headline)
                            }
                            HStack(alignment: .top, spacing: 8) {
                                planPart("Walk there", "\(Int(recommendation.journey.to))m", "figure.walk")
                                planPart("Study", "\(recommendation.studyMinutes)m", "book")
                                planPart("Walk onward", "\(Int(recommendation.journey.onward))m", "arrow.turn.up.right")
                                planPart("Buffer", "\(store.plan.buffer)m", "clock")
                            }
                            Text(store.config.isDemo ? "Synthetic route times & hours · Demo data" : recommendation.journey.estimated ? "Walk times are distance-based estimates; check a walking route." : "Walk times from MapKit · allow extra time for finding a seat.").font(.caption).foregroundStyle(Color.metadata)
                            if recommendation.uncertain { Text("Possible study time only. Confirm hours and entry before you go.").font(.caption).foregroundStyle(Color.metadata) }
                            if store.plan.nextID == nil { Text("Onward travel is excluded until you set a next destination.").font(.caption).foregroundStyle(Color.metadata) }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    Eyebrow(text: "Before you go")
                    Label(store.config.isDemo ? "Open during this synthetic demo plan" : "Hours not confirmed for this date", systemImage: "clock").font(.subheadline)
                    Link("Check official library hours", destination: place.hoursURL).font(.subheadline).frame(minHeight: 44)
                    Label(place.access.label, systemImage: "door.left.hand.open").font(.subheadline)
                    Label("Outlets: \(place.amenities.outlets == true ? "Present; availability varies" : "Not confirmed")", systemImage: "powerplug").font(.subheadline)
                    Label("Wi-Fi: \(place.amenities.wifi == true ? "Present; performance not measured" : "Not confirmed")", systemImage: "wifi").font(.subheadline)
                    if place.amenities.group == true { Label("Group-study spaces · no adjacent-seat guarantee", systemImage: "person.2").font(.subheadline) }
                    if let reservationURL = place.reservationURL { Link(destination: reservationURL) { Label("Open UF room reservations", systemImage: "arrow.up.right.square").frame(minHeight: 44) }.font(.subheadline) }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Location & sources")
                    Text(place.address).font(.subheadline)
                    Text(place.coordinateNote).font(.caption).foregroundStyle(Color.metadata)
                    ForEach(Array(place.sources.enumerated()), id: \.offset) { _, source in
                        Link("Official source · checked \(source.checked)", destination: source.url).font(.caption).frame(minHeight: 44)
                    }
                }
                if let routeError { NoticeView(title: routeError, symbol: "exclamationmark.triangle") }
            }.padding(20).padding(.bottom, 12)
        }
        .background(Color.canvas)
        .navigationTitle(place.shortName).navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                PrimaryButton(title: routing ? "Finding route…" : "Directions", symbol: "figure.walk") { directionTask?.cancel(); directionTask = Task { await directions() } }.disabled(routing)
                Button { sheet = .report } label: { Label("Report", systemImage: "plus.bubble").font(.headline).frame(minWidth: 100, minHeight: 52).padding(.horizontal, 8).background(Color.softForest, in: RoundedRectangle(cornerRadius: 16)) }.accessibilityIdentifier("report-conditions")
            }.padding(.horizontal, 20).padding(.vertical, 12).background(.bar)
        }
        .sheet(item: $sheet) { sheet in
            Group { switch sheet { case .report: ReportView(place: place, initialZone: zoneID); case .evidence: EvidenceView(place: place, zone: zoneID) } }.modifier(DemoSheetLabel())
        }
        .sheet(isPresented: $showRoute) { NavigationStack { RouteView(place: place, route: route, error: routeError) }.modifier(DemoSheetLabel()) }
        .onDisappear { directionTask?.cancel() }
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-screen"), args.count > i + 1, args[i + 1] == "report" { sheet = .report }
        }
    }
    private func planPart(_ name: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { Image(systemName: symbol).foregroundStyle(Color.forest); Text(value).font(.headline).monospacedDigit(); Text(name).font(.caption2).foregroundStyle(Color.metadata).fixedSize(horizontal: false, vertical: true) }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func directions() async {
        routing = true; defer { routing = false }
        routeError = nil
        guard let origin = store.origin, let coordinate = place.coordinate else { routeError = "Choose a manual origin to get walking directions."; showRoute = true; return }
        do { route = try await store.routes.route(from: origin, to: coordinate).route }
        catch { if Task.isCancelled { return }; routeError = "Couldn’t load a walking route. Try again or open the destination in Apple Maps." }
        showRoute = true
    }
}
struct RouteView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let place: Place
    let route: MKRoute?
    let error: String?
    var body: some View {
        VStack(spacing: 16) {
            Map {
                if let coordinate = place.coordinate { Marker(place.shortName, coordinate: coordinate.cl).tint(Color.brandFill) }
                if let route { MapPolyline(route.polyline).stroke(Color.forest, lineWidth: 6) }
            }.mapControls { MapCompass(); MapScaleView() }
            VStack(alignment: .leading, spacing: 12) {
                if let route { Text("\(Int(ceil(route.expectedTravelTime / 60))) min walking").font(.title2.weight(.bold)); Text(Measurement(value: route.distance, unit: UnitLength.meters), format: .measurement(width: .abbreviated, usage: .road)).font(.subheadline) }
                if let error { NoticeView(title: error, symbol: "exclamationmark.triangle") }
                Text("Address destination; the exact usable entrance and indoor route are not verified.").font(.caption).foregroundStyle(Color.metadata)
                PrimaryButton(title: "Open in Apple Maps", symbol: "arrow.up.right") {
                    guard let destination = place.coordinate else { return }
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: destination.cl)); item.name = place.name
                    var items = [item]
                    if let origin = store.origin { let start = MKMapItem(placemark: MKPlacemark(coordinate: origin.cl)); start.name = store.originName; items.insert(start, at: 0) }
                    MKMapItem.openMaps(with: items, launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                }
            }.padding(20)
        }.navigationTitle("Walk to \(place.shortName)").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}

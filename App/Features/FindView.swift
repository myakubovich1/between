import SwiftUI
import MapKit

struct FindView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.betweenReducedMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool
    @State private var pendingWalkFilter = false
    @Namespace private var placeTransition
    @GestureState private var mapDrag: CGFloat = 0
    @State private var path: [String] = []
    @State private var sheet: FindSheet?
    @State private var mapShown = AppConfiguration.current.isDemo
    @State private var mapHeight: CGFloat = 205
    @State private var selected: String?
    @State private var camera: MapCameraPosition = .region(.init(center: .init(latitude: 29.6485, longitude: -82.3435), span: .init(latitudeDelta: 0.012, longitudeDelta: 0.012)))
    private struct ClosedOption: Identifiable {
        let place: Place
        var id: String { "closed-" + place.id }
    }
    private var closedOptions: [ClosedOption] { store.closedPlaces.map { ClosedOption(place: $0) } }
    enum FindSheet: String, Identifiable { case plan, filters, origin, booking; var id: String { rawValue } }
    var body: some View {
        @Bindable var store = store
        Group {
            if typeSize.isAccessibilitySize { accessibleContent } else { regularContent }
        }
        .background(Color.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .animation(BetweenMotion.animation(reduceMotion), value: mapShown)
        .sheet(item: $sheet, onDismiss: { if !store.hasOrigin { pendingWalkFilter = false } }) { item in
            Group {
                switch item {
                case .plan: PlanView()
                case .filters: FiltersView()
                case .origin: OriginView()
                case .booking: BookingPortalView()
                }
            }.modifier(DemoSheetLabel()).presentationDetents([.large]).presentationDragIndicator(.visible).presentationCornerRadius(28)
        }
        .onChange(of: sheet) { _, value in if value != nil { searchFocused = false } }
        .onChange(of: store.hasOrigin) { _, chosen in
            if chosen && pendingWalkFilter { store.filters.maxWalk = 10; store.persistPreferences(); pendingWalkFilter = false }
        }
        .onAppear {
            if sizeClass == .regular { mapShown = true }
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-screen"), args.count > i + 1 {
                let screen = args[i + 1]
                if ["details", "report"].contains(screen), path.isEmpty { path = ["marston"] }
                if screen == "empty" { store.demoNoReports = true; store.recalculateDemo() }
                if screen == "error" { store.demoOffline = true; store.offline = true }
            }
        }
        .navigationDestination(isPresented: Binding(get: { !path.isEmpty }, set: { if !$0 { path = [] } })) {
            if let id = path.first, let place = store.places.first(where: { $0.id == id }) {
                if reduceMotion { PlaceDetailView(place: place) }
                else { PlaceDetailView(place: place).navigationTransition(.zoom(sourceID: id, in: placeTransition)) }
            }
        }
    }
    private var regularContent: some View {
        @Bindable var store = store
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 11) {
                    Image("BrandMark").resizable().frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("between").font(.system(.largeTitle, design: .rounded, weight: .bold)).tracking(-1.8)
                        HStack(spacing: 4) {
                            Circle().fill(Color.ink).frame(width: 5, height: 5)
                            Text("UNIVERSITY OF FLORIDA").font(.system(size: 9, weight: .bold)).tracking(1.6)
                        }.foregroundStyle(Color.metadata)
                    }
                    Spacer(minLength: 0)
                    Button { sheet = .booking } label: {
                        VStack(spacing: 1) {
                            Image(systemName: "calendar.badge.plus").font(.body)
                            Text("Book").font(.system(size: 9, weight: .semibold))
                        }.frame(width: 44, height: 44).foregroundStyle(Color.ink).background(Color.highlight, in: Circle())
                    }.buttonStyle(BetweenPressStyle()).accessibilityLabel("UF room bookings").accessibilityIdentifier("booking-portal")
                    Button { withAnimation(BetweenMotion.animation(reduceMotion)) { mapShown.toggle() } } label: {
                        Image(systemName: mapShown ? "list.bullet" : "map").frame(width: 46, height: 46).background(Color.surface, in: Circle())
                    }.accessibilityLabel(mapShown ? "Show list only" : "Show map").accessibilityIdentifier("toggle-map")
                }
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.metadata)
                    TextField("Search UF libraries", text: $store.query).accessibilityIdentifier("search").onChange(of: store.query) { store.searchChanged() }.submitLabel(.search).focused($searchFocused).onSubmit { store.commitSearch(); searchFocused = false }
                    if !store.query.isEmpty { Button { store.clearSearch(); searchFocused = false } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }.accessibilityLabel("Clear search") }
                }.padding(.horizontal, 14).frame(minHeight: 48).background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
                if !mapShown || sizeClass == .regular {
                Button { sheet = .plan } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.remainingMinutes == 0 ? "Set a new study gap" : "Your study plan").font(.headline)
                            Text(store.nextName.map { "Next: " + $0 } ?? "Add your next class or stop").font(.caption).foregroundStyle(Color.onBrand.opacity(0.75))
                        }
                        Spacer(minLength: 4)
                        VStack(spacing: 0) {
                            Text("\(store.remainingMinutes)").font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                            Text("MIN LEFT").font(.system(size: 8, weight: .bold)).tracking(1)
                        }
                        Image(systemName: "chevron.down").font(.caption.weight(.bold))
                    }.padding(.horizontal, 18).padding(.vertical, 14).foregroundStyle(Color.onBrand).background(Color.brandFill, in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(BetweenPressStyle()).accessibilityIdentifier("time-plan")
                }
            }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
            if mapShown && sizeClass != .regular {
                HStack(spacing: 10) {
                    Button { sheet = .origin } label: { Label(store.hasOrigin ? store.originName : "Set start", systemImage: "mappin.circle").lineLimit(1).frame(maxWidth: .infinity, minHeight: 44).background(Color.surface, in: Capsule()) }.accessibilityIdentifier("origin")
                    Button { sheet = .plan } label: { Label("\(store.remainingMinutes) min left", systemImage: "clock").frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(Color.onBrand).background(Color.brandFill, in: Capsule()) }.accessibilityIdentifier("time-plan")
                }.font(.subheadline.weight(.medium)).buttonStyle(BetweenPressStyle()).padding(.horizontal, 20).padding(.bottom, 10)
            } else {
            Button { sheet = .origin } label: {
                HStack(spacing: 10) {
                    Image(systemName: store.usesLocation ? "location.fill" : "mappin.circle")
                    Text(store.hasOrigin ? "From " + store.originName : "Choose your starting point").lineLimit(1)
                    Spacer(minLength: 4)
                    Text(store.hasOrigin ? "Change" : "Set start").font(.caption.weight(.semibold))
                    Image(systemName: "chevron.right").font(.caption)
                }.font(.subheadline).foregroundStyle(Color.ink).padding(.horizontal, 14).frame(minHeight: 46).background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
            }.buttonStyle(BetweenPressStyle()).padding(.horizontal, 20).padding(.bottom, 10).accessibilityIdentifier("origin")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Pill(title: "Open now", symbol: "clock", active: store.filters.openNow) { store.filters.openNow.toggle(); store.persistPreferences() }
                    Pill(title: "Quiet", symbol: "speaker.slash", active: store.filters.quiet) { store.filters.quiet.toggle(); store.persistPreferences() }
                    Pill(title: "Bookable rooms", symbol: "calendar", active: store.filters.reservableRooms == true) { store.filters.reservableRooms = store.filters.reservableRooms != true; store.persistPreferences() }
                    Pill(title: "Under 10 min", symbol: "figure.walk", active: store.filters.maxWalk == 10) { if store.hasOrigin { store.filters.maxWalk = store.filters.maxWalk == 10 ? 30 : 10; store.persistPreferences() } else { pendingWalkFilter = true; sheet = .origin } }
                    Pill(title: "More", symbol: "line.3.horizontal.decrease", active: store.filters.count > 0) { sheet = .filters }
                }.padding(.horizontal, 20)
            }.padding(.bottom, 10)
            if sizeClass == .regular && !typeSize.isAccessibilitySize {
                HStack(spacing: 0) {
                    if mapShown { campusMap.frame(maxWidth: .infinity) }
                    resultsPanel.frame(width: mapShown ? 420 : nil)
                }
            } else {
                if mapShown && !typeSize.isAccessibilitySize { campusMap.frame(height: min(310, max(130, mapHeight + mapDrag))).transition(.opacity) }
                resultsPanel
            }
        }
    }
    private var accessibleContent: some View {
        @Bindable var store = store
        return List {
            Section {
                Text("Find your in-between").font(.largeTitle.bold())
                Button("UF room bookings") { sheet = .booking }.frame(minHeight: 44).accessibilityIdentifier("booking-portal")
                TextField("Search UF libraries", text: $store.query).accessibilityIdentifier("search").onChange(of: store.query) { store.searchChanged() }.submitLabel(.search).focused($searchFocused).onSubmit { store.commitSearch(); searchFocused = false }
                Button("\(store.remainingMinutes) minutes left · Edit plan") { sheet = .plan }.frame(minHeight: 44).accessibilityIdentifier("time-plan")
                Button(store.hasOrigin ? "From " + store.originName : "Choose your starting point") { sheet = .origin }.frame(minHeight: 44).accessibilityIdentifier("origin")
                Button("Filters · \(store.filters.count) active") { sheet = .filters }.frame(minHeight: 44)
            }
            Section("\(store.results.count) places") {
                if store.offline { NoticeView(title: "Cached conditions · may be old", symbol: "wifi.slash") }
                if store.results.isEmpty && store.closedPlaces.isEmpty {
                    Text(emptyTitle).font(.headline)
                    Text(emptyMessage)
                    if !store.committedQuery.isEmpty { Button("Clear search") { store.clearSearch(); searchFocused = false }.accessibilityIdentifier("empty-clear-search") }
                    if !store.queryMatches.isEmpty {
                        Button("Reset filters") { store.filters = Filters(); store.persistPreferences() }
                        Button("Change study plan") { sheet = .plan }
                    }
                }
                ForEach(store.results) { result in PlaceCard(recommendation: result) { selected = result.id; path = [result.id] }.matchedTransitionSource(id: result.id, in: placeTransition) }
            }
            if !store.closedPlaces.isEmpty {
                Section("Closed right now") {
                    ForEach(closedOptions) { row in ClosedLibraryCard(place: row.place, now: store.now) { path = [row.place.id] }.matchedTransitionSource(id: row.place.id, in: placeTransition) }
                }
            }
            if !store.plan.hasNextDestination { Text("Add your next class to include the onward walk.").font(.footnote) }
        }.listStyle(.plain).scrollContentBackground(.hidden)
    }
    private var campusMap: some View {
        Map(position: $camera, selection: $selected) {
            ForEach(store.results) { result in
                if let c = result.place.coordinate {
                    Annotation(result.place.shortName, coordinate: c.cl) {
                        Button { selected = result.id; path = [result.id] } label: {
                            Image(systemName: result.place.symbol).font(.body.weight(.semibold)).foregroundStyle(Color.onBrand).frame(width: 44, height: 44).background(selected == result.id ? Color.pear : Color.brandFill, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.canvas, lineWidth: 3)).shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                        }.buttonStyle(BetweenPressStyle()).accessibilityLabel("Open \(result.place.name)")
                    }.tag(result.id)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls { MapCompass(); MapScaleView() }
        .overlay(alignment: .bottomTrailing) {
            Button { withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) { camera = .region(.init(center: store.origin?.cl ?? .init(latitude: 29.6485, longitude: -82.3435), span: .init(latitudeDelta: 0.012, longitudeDelta: 0.012))) } } label: { Image(systemName: "scope").frame(width: 44, height: 44).background(.regularMaterial, in: Circle()) }.padding(.trailing, 12).padding(.bottom, 28).accessibilityLabel("Recenter campus map")
        }
        .accessibilityLabel("Campus map. A list of the same places follows.")
    }
    private var emptyTitle: String {
        if store.queryMatches.isEmpty { return "No matching library" }
        if store.remainingMinutes == 0 { return "Your study gap has ended" }
        return "No place fits this plan"
    }
    private var emptyMessage: String {
        if store.queryMatches.isEmpty { return "Try a library name, or clear your search to see every library." }
        if store.remainingMinutes == 0 { return "Set a new gap to plan your next study session." }
        return "Try more time or fewer filters. Closed libraries are listed below when they match your needs."
    }
    private var resultsPanel: some View {
        VStack(spacing: 0) {
            if mapShown && sizeClass != .regular {
                Capsule().fill(.secondary.opacity(0.35)).frame(width: 34, height: 4).frame(maxWidth: .infinity).frame(height: 20).contentShape(Rectangle())
                    .gesture(DragGesture().updating($mapDrag) { value, state, _ in state = value.translation.height }.onEnded { value in
                        let target = mapHeight + value.predictedEndTranslation.height
                        let snap = [CGFloat(130), 205, 310].min(by: { abs($0 - target) < abs($1 - target) }) ?? 205
                        withAnimation(BetweenMotion.animation(reduceMotion)) { mapHeight = snap }
                    })
                    .accessibilityLabel("Resize map").accessibilityAdjustableAction { direction in mapHeight = direction == .increment ? min(310, mapHeight + 50) : max(130, mapHeight - 50) }
            }
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Study options").font(.title3.weight(.bold))
                    Text(store.config.isDemo ? "\(store.results.count) spots for your gap" : "\(store.results.count) \(store.results.count == 1 ? "place" : "places") for now · UF sources").font(.caption).foregroundStyle(Color.metadata)
                }
                Spacer()
                if store.refreshing { ProgressView().controlSize(.small) }
                Button { Task { await store.refresh(force: true) } } label: { Image(systemName: "arrow.clockwise").frame(width: 44, height: 44) }.accessibilityLabel("Refresh conditions")
            }.padding(.horizontal, 20).padding(.bottom, 8)
            ScrollView {
                LazyVStack(spacing: 12) {
                    if let issue = store.officialIssue, !store.config.isDemo { NoticeView(title: issue, symbol: "wifi.exclamationmark") }
                    if store.offline { NoticeView(title: store.lastFetched == nil ? "Conditions unavailable. The campus catalog is still here." : "Offline · showing older cached conditions", symbol: "wifi.slash") }
                    if store.results.isEmpty && store.closedPlaces.isEmpty {
                        ContentUnavailableView {
                            Label(emptyTitle, systemImage: store.queryMatches.isEmpty ? "magnifyingglass" : "clock")
                        } description: { Text(emptyMessage) } actions: {
                            if !store.committedQuery.isEmpty { Button("Clear search") { store.clearSearch(); searchFocused = false }.buttonStyle(.bordered).accessibilityIdentifier("empty-clear-search") }
                            if !store.queryMatches.isEmpty {
                                Button("Reset filters") { store.filters = Filters(); store.persistPreferences() }.buttonStyle(.bordered)
                                Button("Change study plan") { sheet = .plan }
                            }
                        }
                    }
                    ForEach(store.results) { result in
                        PlaceCard(recommendation: result) { selected = result.id; path = [result.id] }.matchedTransitionSource(id: result.id, in: placeTransition)
                    }
                    if !store.closedPlaces.isEmpty {
                        Eyebrow(text: "Closed right now").frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
                        ForEach(closedOptions) { row in
                            ClosedLibraryCard(place: row.place, now: store.now) { path = [row.place.id] }.matchedTransitionSource(id: row.place.id, in: placeTransition)
                        }
                    }
                    if !store.plan.hasNextDestination { Text("Add your next class to include the onward walk.").font(.caption).foregroundStyle(Color.metadata).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8) }
                    Text(store.config.isDemo ? "Student observations, not a seat guarantee." : "Independent app · UF building counts aren’t available-seat counts.").font(.caption2).foregroundStyle(Color.metadata).padding(.bottom, 16)
                }.padding(.horizontal, 20).animation(BetweenMotion.animation(reduceMotion), value: store.results.map(\.id))
            }.scrollDismissesKeyboard(.interactively).refreshable { await store.refresh(force: true) }
        }.background(Color.canvas)
    }
}

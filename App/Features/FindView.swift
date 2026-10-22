import SwiftUI
import MapKit

struct FindView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var path: [String] = []
    @State private var sheet: FindSheet?
    @State private var mapShown = true
    @State private var mapHeight: CGFloat = 205
    @State private var selected: String?
    @State private var camera: MapCameraPosition = .region(.init(center: .init(latitude: 29.6485, longitude: -82.3435), span: .init(latitudeDelta: 0.012, longitudeDelta: 0.012)))
    enum FindSheet: String, Identifiable { case plan, filters, origin; var id: String { rawValue } }
    var body: some View {
        @Bindable var store = store
        Group {
            if typeSize.isAccessibilitySize { accessibleContent } else { regularContent }
        }
        .background(Color.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $sheet) { item in
            Group {
                switch item {
                case .plan: PlanView()
                case .filters: FiltersView()
                case .origin: OriginView()
                }
            }.modifier(DemoSheetLabel())
        }
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-screen"), args.count > i + 1 {
                let screen = args[i + 1]
                if ["details", "report"].contains(screen), path.isEmpty { path = ["marston"] }
                if screen == "empty" { store.demoNoReports = true; store.recalculateDemo() }
                if screen == "error" { store.demoOffline = true; store.offline = true }
            }
        }
        .navigationDestination(isPresented: Binding(get: { !path.isEmpty }, set: { if !$0 { path = [] } })) {
            if let id = path.first, let place = store.places.first(where: { $0.id == id }) { PlaceDetailView(place: place) }
        }
    }
    private var regularContent: some View {
        @Bindable var store = store
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.config.name.lowercased()).font(.system(.largeTitle, design: .rounded, weight: .bold)).tracking(-1.8)
                        Text("Make room for a little focus.").font(.subheadline).foregroundStyle(Color.metadata)
                    }
                    Spacer()
                    Button { mapShown.toggle() } label: { Image(systemName: mapShown ? "list.bullet" : "map").frame(width: 46, height: 46).background(Color(.secondarySystemGroupedBackground), in: Circle()) }.accessibilityLabel(mapShown ? "Show list only" : "Show map").accessibilityIdentifier("toggle-map")
                }
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.metadata)
                    TextField("Find a campus spot", text: $store.query).accessibilityIdentifier("search").onChange(of: store.query) { store.searchChanged() }.submitLabel(.search)
                    if !store.query.isEmpty { Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }.accessibilityLabel("Clear search") }
                }.padding(.horizontal, 14).frame(minHeight: 48).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                Button { sheet = .plan } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "hourglass").font(.title2).frame(width: 42, height: 44).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("I have \(store.plan.available) minutes").font(.headline)
                            Text(store.next.map { "Then to \($0.shortName)" } ?? "Find your in-between place").font(.caption).opacity(0.85)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                    }.padding(12).foregroundStyle(.white).background(Color.brandFill, in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain).accessibilityIdentifier("time-plan")
            }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Pill(title: "Open now", symbol: "clock", active: store.filters.openNow) { store.filters.openNow.toggle(); store.persistPreferences() }
                    Pill(title: "Quiet", symbol: "speaker.slash", active: store.filters.quiet) { store.filters.quiet.toggle(); store.persistPreferences() }
                    Pill(title: "Outlets", symbol: "powerplug", active: store.filters.outlets) { store.filters.outlets.toggle(); store.persistPreferences() }
                    Pill(title: "Under 10 min", symbol: "figure.walk", active: store.filters.maxWalk == 10) { store.filters.maxWalk = store.filters.maxWalk == 10 ? 30 : 10; store.persistPreferences() }
                    Pill(title: "More", symbol: "line.3.horizontal.decrease", active: store.filters.count > 0) { sheet = .filters }
                }.padding(.horizontal, 20)
            }.padding(.bottom, 10)
            if sizeClass == .regular && !typeSize.isAccessibilitySize {
                HStack(spacing: 0) {
                    if mapShown { campusMap.frame(maxWidth: .infinity) }
                    resultsPanel.frame(width: mapShown ? 420 : nil)
                }
            } else {
                if mapShown && !typeSize.isAccessibilitySize { campusMap.frame(height: mapHeight) }
                resultsPanel
            }
        }
    }
    private var accessibleContent: some View {
        @Bindable var store = store
        return List {
            Section {
                Text("Find your in-between").font(.largeTitle.bold())
                TextField("Find a campus spot", text: $store.query).onChange(of: store.query) { store.searchChanged() }
                Button("I have \(store.plan.available) minutes") { sheet = .plan }.frame(minHeight: 44)
                Button("From \(store.originName)") { sheet = .origin }.frame(minHeight: 44)
                Button("Filters · \(store.filters.count) active") { sheet = .filters }.frame(minHeight: 44)
            }
            Section("\(store.results.count) places") {
                if store.offline { NoticeView(title: "Cached conditions · may be old", symbol: "wifi.slash") }
                if store.results.isEmpty {
                    Text("Nothing matches. Try more time or relax a filter.")
                    Button("Reset filters") { store.filters = Filters(); store.persistPreferences() }
                }
                ForEach(store.results) { result in PlaceCard(recommendation: result) { selected = result.id; path = [result.id] } }
            }
            if store.plan.nextID == nil { Text("Your plan excludes travel to your next commitment.").font(.footnote) }
        }.listStyle(.plain).scrollContentBackground(.hidden)
    }
    private var campusMap: some View {
        Map(position: $camera, selection: $selected) {
            ForEach(store.results) { result in
                if let c = result.place.coordinate {
                    Annotation(result.place.shortName, coordinate: c.cl) {
                        Button { selected = result.id; path = [result.id] } label: {
                            Image(systemName: result.place.symbol).font(.body.weight(.semibold)).foregroundStyle(selected == result.id ? Color.brandFill : .white).frame(width: 44, height: 44).background(selected == result.id ? Color.white : Color.brandFill, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(.white, lineWidth: 3)).shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                        }.buttonStyle(.plain).accessibilityLabel("Open \(result.place.name)")
                    }.tag(result.id)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls { MapCompass(); MapScaleView() }
        .overlay(alignment: .topLeading) {
            Button { sheet = .origin } label: { Label("From \(store.originName)", systemImage: "location.circle").font(.caption.weight(.semibold)).padding(.horizontal, 12).frame(minHeight: 44).background(.regularMaterial, in: Capsule()) }.padding(12).accessibilityIdentifier("origin")
        }
        .overlay(alignment: .bottomTrailing) {
            Button { camera = .region(.init(center: store.origin?.cl ?? .init(latitude: 29.6485, longitude: -82.3435), span: .init(latitudeDelta: 0.012, longitudeDelta: 0.012))) } label: { Image(systemName: "scope").frame(width: 44, height: 44).background(.regularMaterial, in: Circle()) }.padding(.trailing, 12).padding(.bottom, 28).accessibilityLabel("Recenter campus map")
        }
        .accessibilityLabel("Campus map. A list of the same places follows.")
    }
    private var resultsPanel: some View {
        VStack(spacing: 0) {
            if mapShown && sizeClass != .regular {
                Capsule().fill(.secondary.opacity(0.35)).frame(width: 34, height: 4).frame(maxWidth: .infinity).frame(height: 20).contentShape(Rectangle())
                    .gesture(DragGesture().onEnded { value in mapHeight = min(310, max(130, mapHeight + value.translation.height)) })
                    .accessibilityLabel("Resize map").accessibilityAdjustableAction { direction in mapHeight = direction == .increment ? min(310, mapHeight + 50) : max(130, mapHeight - 50) }
            }
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("A good place to land").font(.title3.weight(.bold))
                    Text("\(store.results.count) spots for your gap").font(.caption).foregroundStyle(Color.metadata)
                }
                Spacer()
                if store.refreshing { ProgressView().controlSize(.small) }
                Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise").frame(width: 44, height: 44) }.accessibilityLabel("Refresh conditions")
            }.padding(.horizontal, 20).padding(.bottom, 8)
            ScrollView {
                LazyVStack(spacing: 12) {
                    if store.offline { NoticeView(title: store.lastFetched == nil ? "Conditions unavailable. The campus catalog is still here." : "Offline · showing older cached conditions", symbol: "wifi.slash") }
                    if !mapShown { Button { sheet = .origin } label: { Label("From \(store.originName)", systemImage: "location.circle").frame(minHeight: 44) } }
                    if store.results.isEmpty {
                        ContentUnavailableView {
                            Label("Nothing fits just yet", systemImage: "leaf")
                        } description: { Text("Try more time or relax a filter. Unknown amenities never count as a match.") } actions: {
                            Button("Reset filters") { store.filters = Filters(); store.persistPreferences() }.buttonStyle(.bordered)
                            Button("Change time") { sheet = .plan }
                        }
                    }
                    ForEach(store.results) { result in
                        PlaceCard(recommendation: result) { selected = result.id; path = [result.id] }
                    }
                    if store.plan.nextID == nil { Text("No next destination set. Plans exclude travel to your next commitment.").font(.caption).foregroundStyle(Color.metadata).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8) }
                    Text("Student observations, not a seat guarantee.").font(.caption2).foregroundStyle(Color.metadata).padding(.bottom, 16)
                }.padding(.horizontal, 20)
            }.refreshable { await store.refresh() }
        }.background(Color.canvas)
    }
}

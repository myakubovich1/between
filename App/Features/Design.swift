import SwiftUI

// Filled brand colors keep black labels in both appearances.
extension Color {
    static let cornflower = Color("Cornflower")
    static let pear = Color("Pear")
    static let brandFill = Color.cornflower
    static let onBrand = Color.black
    static let metadata = Color("Metadata")
    static let canvas = Color("Canvas")
    static let ink = Color("Ink")
    static let surface = Color("Mist")
    static let highlight = Color("Highlight")
}

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(18).background(Color.surface, in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(.primary.opacity(0.05))) }
}
struct Eyebrow: View {
    var text: String
    var body: some View { Text(text.uppercased()).font(.caption2.weight(.bold)).tracking(1.8).foregroundStyle(Color.metadata) }
}
struct StatusLabel: View {
    let evidence: Evidence
    var now: Date
    var body: some View {
        Label(evidence.label(at: now), systemImage: evidence.current(at: now) ? (evidence.differs ? "arrow.left.arrow.right" : evidence.seat?.symbol ?? "questionmark.circle") : "questionmark.circle")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(evidence.current(at: now) ? Color.ink : Color.metadata)
    }
}
struct EvidenceCaption: View {
    let evidence: Evidence
    var now: Date
    var body: some View {
        if evidence.current(at: now), let newest = evidence.newestAt {
            Text("\(evidence.reporters == 1 ? "One student report" : "\(evidence.reporters) independent reports") · \(max(0, Int(now.timeIntervalSince(newest) / 60)))m ago")
                .font(.caption).foregroundStyle(Color.metadata)
        } else { Text("A fresh update would help someone.").font(.caption).foregroundStyle(Color.metadata) }
    }
}
struct Pill: View {
    @Environment(\.betweenReducedMotion) private var reduceMotion
    var title: String
    var symbol: String
    var active = false
    var action: () -> Void
    var body: some View {
        Button(action: action) { Label(title, systemImage: symbol).font(.subheadline.weight(.medium)).padding(.horizontal, 14).frame(minHeight: 44).background(active ? Color.pear : Color.surface, in: Capsule()).foregroundStyle(active ? Color.onBrand : Color.ink).overlay(Capsule().stroke(active ? Color.black : Color.ink.opacity(0.10), lineWidth: active ? 1.5 : 1)) }
            .buttonStyle(BetweenPressStyle()).animation(BetweenMotion.animation(reduceMotion), value: active).accessibilityAddTraits(active ? .isSelected : [])
    }
}
struct PrimaryButton: View {
    var title: String
    var symbol: String
    var action: () -> Void
    var body: some View {
        Button(action: action) { Label(title, systemImage: symbol).font(.headline).frame(maxWidth: .infinity, minHeight: 52).foregroundStyle(Color.onBrand).background(Color.brandFill, in: RoundedRectangle(cornerRadius: 16)) }.buttonStyle(BetweenPressStyle())
    }
}
struct PlaceCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.betweenReducedMotion) private var reduceMotion
    var recommendation: Recommendation
    var open: () -> Void
    private var place: Place { recommendation.place }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: place.symbol).font(.body).foregroundStyle(Color.ink).frame(width: 38, height: 38).background(Color.highlight, in: RoundedRectangle(cornerRadius: 12))
                Button(action: open) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.shortName).font(.headline).foregroundStyle(Color.ink)
                        Text(store.config.isDemo ? "Demo hours" : place.hoursLabel(at: store.now)).font(.caption).foregroundStyle(Color.metadata)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("place-\(place.id)")
                Button { store.toggleSave(place) } label: {
                    Image(systemName: store.favorites.contains(place.id) ? "bookmark.fill" : "bookmark").frame(width: 44, height: 44).foregroundStyle(Color.ink)
                }.buttonStyle(BetweenPressStyle()).accessibilityLabel(store.favorites.contains(place.id) ? "Unsave \(place.name)" : "Save \(place.name)")
            }
            Button(action: open) {
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
                layout {
                    VStack(alignment: .leading, spacing: 6) {
                        if store.config.isDemo {
                            StatusLabel(evidence: store.status(place: place.id), now: store.now)
                            EvidenceCaption(evidence: store.status(place: place.id), now: store.now)
                        } else {
                            OfficialCountLabel(observation: store.officialOccupancy[place.id], now: store.now, refreshFailed: store.occupancyFailures.contains(place.id), loading: store.refreshing && !store.hasRefreshedOfficial)
                        }
                        if store.hasOrigin {
                            Label("\(Int(recommendation.journey.to)) min walk\(recommendation.journey.estimated ? " · est." : "")", systemImage: "figure.walk").font(.caption).foregroundStyle(Color.metadata)
                        } else { Label("Set a start for walking time", systemImage: "mappin.circle").font(.caption).foregroundStyle(Color.metadata) }
                        if place.reservationURL != nil { Label("Bookable rooms or carrels", systemImage: "calendar").font(.caption).foregroundStyle(Color.metadata) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if store.hasOrigin {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(recommendation.studyMinutes)").font(.system(size: 36, weight: .semibold, design: .rounded)).monospacedDigit().contentTransition(.numericText()).animation(BetweenMotion.animation(reduceMotion), value: recommendation.studyMinutes).foregroundStyle(Color.ink).padding(.horizontal, 10).background(Color.highlight, in: RoundedRectangle(cornerRadius: 12))
                        Text("min study est.").font(.caption2).foregroundStyle(Color.metadata)
                    }
                    }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            if !store.config.isDemo && store.communityAvailable {
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    Label(store.status(place: place.id).label(at: store.now), systemImage: "bubble.left").font(.caption).foregroundStyle(Color.metadata)
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold)).foregroundStyle(Color.ink)
                }
            }
            if place.hours == nil { Text("Confirm opening hours before you leave.").font(.caption2).foregroundStyle(Color.metadata) }
        }.padding(18).background(Color.surface, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.ink.opacity(0.08)))
    }
}
struct OfficialCountLabel: View {
    @Environment(\.betweenReducedMotion) private var reduceMotion
    var observation: OfficialOccupancy?
    var now: Date
    var expanded = false
    var refreshFailed = false
    var loading = false
    var area = "building"
    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 10 : 4) {
            if let observation, let count = observation.count {
                let current = observation.hasRecentRetrieval(at: now) && !refreshFailed
                Label("\(count.formatted()) \(count == 1 ? "person" : "people") in \(area)", systemImage: "person.2")
                    .font(expanded ? .title3.weight(.semibold) : .subheadline.weight(.semibold)).foregroundStyle(Color.ink)
                    .contentTransition(.numericText()).animation(BetweenMotion.animation(reduceMotion), value: count)
                Text("\(current ? "UF count" : "Saved UF count") · retrieved \(max(0, Int(now.timeIntervalSince(observation.retrievedAt) / 60)))m ago").font(.caption).foregroundStyle(Color.metadata)
                if !current { Label("Refresh unavailable · count may be old", systemImage: "clock.badge.exclamationmark").font(.caption).foregroundStyle(Color.metadata) }
                if expanded {
                    Text("UF publishes people counts, not available seats. Its display provides no sensor timestamp, so retrieval time does not establish the age of the measurement.").font(.footnote).foregroundStyle(Color.metadata)
                }
            } else {
                Label(loading ? "Loading UF count…" : "UF count unavailable", systemImage: loading ? "arrow.triangle.2.circlepath" : "person.2").font(.subheadline.weight(.semibold)).foregroundStyle(Color.metadata)
                if !loading { Text("Check UF’s occupancy page").font(.caption).foregroundStyle(Color.metadata) }
            }
        }.accessibilityElement(children: .combine)
    }
}
struct NoticeView: View {
    var title: String
    var symbol: String = "info.circle"
    var body: some View { Label(title, systemImage: symbol).font(.footnote).frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color.highlight, in: RoundedRectangle(cornerRadius: 12)).accessibilityElement(children: .combine) }
}

struct DemoBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkle")
            Text("Demo data").fontWeight(.semibold)
            Text("· UF campus").foregroundStyle(Color.metadata)
        }.font(.caption2).frame(maxWidth: .infinity).padding(.vertical, 5).background(Color.highlight).accessibilityIdentifier("demo-label")
    }
}
struct DemoSheetLabel: ViewModifier {
    @Environment(AppStore.self) private var store
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if store.config.isDemo { DemoBanner() }
        }
    }
}

#if DEBUG
@MainActor private struct PlaceComponentPreview: View {
    @State private var store = AppStore(config: .init(mode: .demo, name: "Between", url: nil, key: ""))
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(store.results.prefix(2)) { result in PlaceCard(recommendation: result) {} }
                NoticeView(title: "Offline · showing older cached conditions", symbol: "wifi.slash")
                StatusLabel(evidence: .empty(place: "missing", now: store.now), now: store.now)
            }.padding(20)
        }.background(Color.canvas).environment(store)
        .onAppear {
            store.filters = Filters()
            if let index = store.places.firstIndex(where: { $0.id == "west" }) {
                store.places[index].shortName = "Library with a very long name and missing amenities"
            }
            store.displayTime = store.displayTime.addingTimeInterval(1900)
        }
    }
}
#Preview("Cards · long name, expired evidence") { PlaceComponentPreview() }
#Preview("Cards · accessibility and dark mode") { PlaceComponentPreview().dynamicTypeSize(.accessibility2).preferredColorScheme(.dark) }
#endif

/// Short, interruptible native motion, with a full opt-out for Reduce Motion.
enum BetweenMotion {
    static func animation(_ reduced: Bool) -> Animation? { reduced ? nil : .spring(response: 0.36, dampingFraction: 0.88) }
}
struct BetweenPressStyle: ButtonStyle {
    @Environment(\.betweenReducedMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
struct ClosedLibraryCard: View {
    let place: Place
    let now: Date
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "moon.zzz").frame(width: 38, height: 38).background(Color.highlight, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Text(place.shortName).font(.headline)
                    Text("Closed · " + place.nextOpeningLabel(at: now)).font(.caption).foregroundStyle(Color.metadata)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption)
            }.foregroundStyle(Color.ink).padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Color.surface, in: RoundedRectangle(cornerRadius: 22))
        }.buttonStyle(BetweenPressStyle()).accessibilityIdentifier("closed-\(place.id)")
    }
}

private struct BetweenReducedMotionKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var betweenReducedMotion: Bool {
        get { self[BetweenReducedMotionKey.self] }
        set { self[BetweenReducedMotionKey.self] = newValue }
    }
}

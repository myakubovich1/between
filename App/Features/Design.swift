import SwiftUI

extension Color {
    static let brandFill = Color(red: 18.0/255, green: 63.0/255, blue: 53.0/255)
    static let forest = Color("Forest")
    static let metadata = Color("Metadata")
    static let canvas = Color("Canvas")
    static let ink = Color("Ink")
    static let softForest = Color("SoftForest")
}
struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(18).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(.primary.opacity(0.05))) }
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
            .foregroundStyle(evidence.current(at: now) ? Color.forest : Color.metadata)
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
    var title: String
    var symbol: String
    var active = false
    var action: () -> Void
    var body: some View {
        Button(action: action) { Label(title, systemImage: symbol).font(.subheadline.weight(.medium)).padding(.horizontal, 14).frame(minHeight: 44).background(active ? Color.brandFill : Color(.secondarySystemGroupedBackground), in: Capsule()).foregroundStyle(active ? Color.white : Color.ink).overlay(Capsule().stroke(.primary.opacity(active ? 0 : 0.10))) }
            .buttonStyle(.plain).accessibilityAddTraits(active ? .isSelected : [])
    }
}
struct PrimaryButton: View {
    var title: String
    var symbol: String
    var action: () -> Void
    var body: some View {
        Button(action: action) { Label(title, systemImage: symbol).font(.headline).frame(maxWidth: .infinity, minHeight: 52).foregroundStyle(.white).background(Color.brandFill, in: RoundedRectangle(cornerRadius: 16)) }.buttonStyle(.plain)
    }
}
struct PlaceCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    var recommendation: Recommendation
    var open: () -> Void
    private var place: Place { recommendation.place }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: place.symbol).font(.body).foregroundStyle(Color.forest).frame(width: 38, height: 38).background(Color.softForest, in: RoundedRectangle(cornerRadius: 12))
                Button(action: open) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.shortName).font(.headline).foregroundStyle(Color.ink)
                        Text(store.config.isDemo ? "Demo hours" : place.hoursLabel(at: store.now)).font(.caption).foregroundStyle(Color.metadata)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("place-\(place.id)")
                Button { store.toggleSave(place) } label: {
                    Image(systemName: store.favorites.contains(place.id) ? "bookmark.fill" : "bookmark").frame(width: 44, height: 44).foregroundStyle(Color.forest)
                }.buttonStyle(.plain).accessibilityLabel(store.favorites.contains(place.id) ? "Unsave \(place.name)" : "Save \(place.name)")
            }
            Button(action: open) {
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
                layout {
                    VStack(alignment: .leading, spacing: 6) {
                        if store.config.isDemo {
                            StatusLabel(evidence: store.status(place: place.id), now: store.now)
                            EvidenceCaption(evidence: store.status(place: place.id), now: store.now)
                        } else {
                            OfficialCountLabel(observation: store.officialOccupancy[place.id], now: store.now)
                        }
                        Label("\(Int(recommendation.journey.to)) min walk\(recommendation.journey.estimated ? " · est." : "")", systemImage: "figure.walk").font(.caption).foregroundStyle(Color.metadata)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(recommendation.studyMinutes)").font(.system(size: 36, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(Color.forest)
                        Text(recommendation.uncertain ? "min possible*" : "min to study").font(.caption2).foregroundStyle(Color.metadata)
                    }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            if !store.config.isDemo {
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    Label(store.status(place: place.id).label(at: store.now), systemImage: "bubble.left").font(.caption).foregroundStyle(Color.metadata)
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold)).foregroundStyle(Color.forest)
                }
            }
            if recommendation.uncertain { Text("*Confirm entry\(place.hours == nil ? " & hours" : "") before you go").font(.caption2).foregroundStyle(Color.metadata) }
        }.padding(18).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.forest.opacity(0.08)))
    }
}
struct OfficialCountLabel: View {
    var observation: OfficialOccupancy?
    var now: Date
    var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 10 : 4) {
            if let observation, let count = observation.count {
                Label("\(count.formatted()) people in building", systemImage: "person.2").font(expanded ? .title3.weight(.semibold) : .subheadline.weight(.semibold)).foregroundStyle(Color.ink)
                Text("UF count · retrieved \(max(0, Int(now.timeIntervalSince(observation.retrievedAt) / 60)))m ago").font(.caption).foregroundStyle(Color.metadata)
                Text("Sensor update time unavailable").font(.caption2).foregroundStyle(Color.metadata)
                if expanded {
                    Text("This is the published building count, not a count of available seats. Counts can lag; a fresh retrieval doesn’t establish the sensor’s age.").font(.footnote).foregroundStyle(Color.metadata)
                }
            } else {
                Label("UF count unavailable", systemImage: "person.2").font(.subheadline.weight(.semibold)).foregroundStyle(Color.metadata)
                Text("Check UF’s occupancy page").font(.caption).foregroundStyle(Color.metadata)
            }
        }.accessibilityElement(children: .combine)
    }
}
struct NoticeView: View {
    var title: String
    var symbol: String = "info.circle"
    var body: some View { Label(title, systemImage: symbol).font(.footnote).frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color.softForest, in: RoundedRectangle(cornerRadius: 12)).accessibilityElement(children: .combine) }
}

struct DemoBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkle")
            Text("Demo data").fontWeight(.semibold)
            Text("· UF campus").foregroundStyle(Color.metadata)
        }.font(.caption2).frame(maxWidth: .infinity).padding(.vertical, 5).background(Color.softForest).accessibilityIdentifier("demo-label")
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

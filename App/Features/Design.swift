import SwiftUI

extension Color {
    static let brandFill = Color(red: 28.0/255, green: 107.0/255, blue: 90.0/255)
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
    var recommendation: Recommendation
    var open: () -> Void
    private var place: Place { recommendation.place }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Image(systemName: place.symbol).font(.title3).foregroundStyle(Color.forest).frame(width: 44, height: 44).background(Color.softForest, in: RoundedRectangle(cornerRadius: 13))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(place.shortName).font(.headline).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                            Text("\(Int(recommendation.journey.to)) min walk\(store.config.isDemo ? " · demo route" : recommendation.journey.estimated ? " · estimate" : "")").font(.caption).foregroundStyle(Color.metadata)
                        }
                        Spacer(minLength: 0)
                    }
                    StatusLabel(evidence: store.status(place: place.id), now: store.now)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(recommendation.studyMinutes)").font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(Color.forest)
                        Text(recommendation.uncertain ? "min possible study*" : "min to settle in").font(.caption).foregroundStyle(Color.metadata)
                    }
                    Text(recommendation.uncertain ? "*Check hours & entry before you go" : store.config.isDemo ? "Open during this demo plan" : "Open for this plan").font(.caption).foregroundStyle(Color.metadata)
                    if store.filters.preferredNoise != nil && (!store.status(place: place.id).current(at: store.now) || store.status(place: place.id).noise == nil) {
                        Text("Sound preference not yet confirmed").font(.caption).foregroundStyle(Color.metadata)
                    }
                    EvidenceCaption(evidence: store.status(place: place.id), now: store.now)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("place-\(place.id)")
            Button { store.toggleSave(place) } label: { Image(systemName: store.favorites.contains(place.id) ? "bookmark.fill" : "bookmark").font(.body).frame(width: 44, height: 44).foregroundStyle(Color.forest) }.buttonStyle(.plain).accessibilityLabel(store.favorites.contains(place.id) ? "Unsave \(place.name)" : "Save \(place.name)")
        }
        .padding(16).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(.primary.opacity(0.06)))
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

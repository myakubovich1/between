import SwiftUI
import MapKit

/// UF campus directory with genuine bundled building fallbacks and MapKit search.
struct CampusPlacePicker: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let title: String
    var allowNone = false
    var select: (CampusDestination?) -> Void
    @State private var query = ""
    @State private var results: [CampusDestination] = []
    @State private var searching = false
    @State private var issue: String?
    var body: some View {
        NavigationStack {
            List {
                if allowNone && query.isEmpty {
                    Section { Button("No next stop") { select(nil); dismiss() } }
                }
                if query.isEmpty {
                    Section("Campus buildings") {
                        ForEach(["Turlington Hall", "Heavener Hall", "Norman Hall", "Reitz Union", "Newell Hall"], id: \.self) { name in
                            Button { query = name } label: { Label(name, systemImage: "building.2").frame(minHeight: 44) }
                        }
                    }
                    Section("Libraries") {
                        ForEach(store.places) { place in
                            if let coordinate = place.coordinate {
                                destinationRow(.init(id: place.id, name: place.shortName, coordinate: coordinate, address: place.address))
                            }
                        }
                    }
                } else {
                    if searching { HStack { ProgressView(); Text("Searching campus…") } }
                    if let issue { Text(issue).foregroundStyle(Color.metadata) }
                    ForEach(results) { destinationRow($0) }
                    if !searching && results.isEmpty && issue == nil { ContentUnavailableView.search(text: query) }
                }
            }.scrollContentBackground(.hidden).background(Color.canvas)
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .searchable(text: $query, prompt: "Building or campus address")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .task(id: query) {
            let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 2 else { results = []; searching = false; issue = nil; return }
            do {
                searching = true; issue = nil
                results = CampusBuildingDirectory.bundled().filter { CampusBuildingDirectory.matches($0, query: text) }
                try await Task.sleep(for: .milliseconds(250))
                if let buildings = try? await CampusBuildingDirectory.search(text), !buildings.isEmpty {
                    guard !Task.isCancelled else { return }
                    results = buildings; searching = false; return
                }
                if !results.isEmpty { searching = false; return }
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = text
                request.region = .init(center: .init(latitude: 29.6465, longitude: -82.3435), span: .init(latitudeDelta: 0.06, longitudeDelta: 0.06))
                request.resultTypes = [.address, .pointOfInterest]
                let search = CampusSearchHandle(request: request)
                let response = try await withTaskCancellationHandler { try await search.start() } onCancel: { Task { @MainActor in search.cancel() } }
                guard !Task.isCancelled else { return }
                let campus = Coordinate(latitude: 29.6465, longitude: -82.3435)
                var found: [CampusDestination] = []
                for item in response.mapItems {
                    let coordinate = Coordinate(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
                    guard campus.distance(to: coordinate) < 12_000, let name = item.name else { continue }
                    let result = CampusDestination(id: "map-\(coordinate.latitude)-\(coordinate.longitude)", name: name, coordinate: coordinate, address: item.placemark.title)
                    if !found.contains(where: { $0.id == result.id }) { found.append(result) }
                }
                results = found; searching = false
            } catch {
                guard !Task.isCancelled else { return }
                searching = false; results = []; issue = "Campus search couldn’t load. Try again or choose a library."
            }
        }
    }
    private func destinationRow(_ destination: CampusDestination) -> some View {
        Button { select(destination); dismiss() } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(destination.name).foregroundStyle(Color.ink)
                if let address = destination.address { Text(address).font(.caption).foregroundStyle(Color.metadata) }
                else if destination.sourceURL != nil { Text((destination.abbreviation.map { $0 + " · " } ?? "") + "UF campus map").font(.caption).foregroundStyle(Color.metadata) }
            }.frame(minHeight: 44, alignment: .leading)
        }.accessibilityIdentifier("campus-place-\(destination.id)")
    }
}
@MainActor private final class CampusSearchHandle {
    private let search: MKLocalSearch
    init(request: MKLocalSearch.Request) { search = MKLocalSearch(request: request) }
    func start() async throws -> MKLocalSearch.Response { try await search.start() }
    func cancel() { search.cancel() }
}

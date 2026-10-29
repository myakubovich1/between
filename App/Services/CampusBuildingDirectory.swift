import Foundation

/// Public building search used by campusmap.ufl.edu. Bundled common buildings are an actual source snapshot.
enum CampusBuildingDirectory {
    struct Building: Decodable {
        var BLDGCODE: String
        var BLDG: String
        var NAME: String
        var ABBREV: String?
        var LAT: Double?
        var LON: Double?
    }
    static func parse(_ data: Data) throws -> [CampusDestination] {
        try JSONDecoder().decode([Building].self, from: data).compactMap { building in
            guard let lat = building.LAT, let lon = building.LON, lat.isFinite, lon.isFinite,
                  (29.55...29.75).contains(lat), (-82.45 ... -82.25).contains(lon), !building.NAME.isEmpty else { return nil }
            return CampusDestination(id: "uf-" + building.BLDGCODE, name: building.NAME, coordinate: .init(latitude: lat, longitude: lon), address: nil, abbreviation: building.ABBREV,
                                     sourceURL: URL(string: "https://campusmap.ufl.edu/#/index/" + building.BLDG))
        }
    }
    static func matches(_ destination: CampusDestination, query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return !words.isEmpty && words.allSatisfy { word in
            destination.name.localizedStandardContains(word) || destination.abbreviation?.localizedStandardContains(word) == true
        }
    }
    static func bundled() -> [CampusDestination] {
        guard let url = Bundle.main.url(forResource: "campus-buildings", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [] }
        return (try? parse(data)) ?? []
    }
    static func search(_ query: String) async throws -> [CampusDestination] {
        var url = URLComponents(string: "https://campusmap.ufl.edu/library/api/searchBldg")!
        url.queryItems = [.init(name: "srch", value: query)]
        return try parse(await UFHTTP.fetch(url.url!, maxBytes: 1_000_000))
    }
}

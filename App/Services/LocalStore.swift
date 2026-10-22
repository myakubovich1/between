import Foundation

struct LocalSnapshot: Codable, Sendable {
    var version = 1
    var evidence: [Evidence]
    var fetchedAt: Date
    var demoReports: [CommunityObservation]?
    var catalog: [Place]?
    var officialOccupancy: [String: OfficialOccupancy]?
}
actor LocalCache {
    private let mode: String
    init(mode: String) { self.mode = mode }
    private func file() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = base.appendingPathComponent("Between", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("\(mode)-cache-v1.json")
    }
    func read() throws -> LocalSnapshot? {
        let url = try file()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let snapshot = try JSONDecoder.between.decode(LocalSnapshot.self, from: Data(contentsOf: url))
        guard snapshot.version == 1 else { throw AppFailure.message("The conditions cache needs a refresh. Your saved places are safe.") }
        return snapshot
    }
    func write(_ snapshot: LocalSnapshot) throws { try JSONEncoder.between.encode(snapshot).write(to: file(), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    func clear() throws { let url = try file(); if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) } }
}

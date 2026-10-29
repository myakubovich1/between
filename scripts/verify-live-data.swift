import Foundation

enum AppFailure: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): text } }
}
@main struct VerifyLiveUF {
    static func main() async throws {
        let service = UFLibraryData()
        async let occupancy = service.occupancy(force: true)
        async let hours = service.hours(force: true)
        let (counts,schedules) = try await (occupancy,hours)
        var output: [String: Any] = ["retrievedAt":ISO8601DateFormatter().string(from: Date()), "buildingSchedules":schedules.count, "failedCounts":Array(counts.failed).sorted()]
        output["counts"] = counts.observations.mapValues { ["count":$0.count ?? -1, "retrievedAt":ISO8601DateFormatter().string(from:$0.retrievedAt), "sensorTimestampSupplied":$0.observedAt != nil] as [String:Any] }
        let rooms = StudyRoomService()
        let start = StudyRoomService.nextSlot(after: Date())
        var searches: [String: Any] = [:]
        for place in RoomLocation.all.keys.sorted() {
            do {
                let result = try await rooms.availability(placeID:place,start:start,force:true)
                searches[place] = ["total":result.total,"parsed":result.rooms.count,"names":result.rooms.map(\.name),"url":result.searchURL.absoluteString]
            } catch { searches[place] = ["error":error.localizedDescription] }
        }
        output["rooms"] = searches
        let data = try JSONSerialization.data(withJSONObject:output,options:[.prettyPrinted,.sortedKeys])
        print(String(decoding:data,as:UTF8.self))
        guard counts.observations.count == 11, schedules.count == 6, !searches.values.contains(where: { ($0 as? [String:Any])?["error"] != nil }) else { throw URLError(.badServerResponse) }
    }
}

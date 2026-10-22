import Foundation
import Supabase

struct AppConfiguration: Sendable {
    enum Mode: String { case demo, development, release }
    let mode: Mode
    let name: String
    let url: URL?
    let key: String
    static var current: Self {
        func value(_ key: String) -> String { Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "" }
        return .init(mode: Mode(rawValue: value("BetweenMode")) ?? .release, name: Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Between", url: URL(string: value("SupabaseURL")), key: value("SupabasePublishableKey"))
    }
    var isDemo: Bool { mode == .demo }
    var configured: Bool {
        guard let url, !key.isEmpty else { return false }
        return url.scheme == "https" || (mode == .development && url.scheme == "http" && ["localhost", "127.0.0.1"].contains(url.host ?? ""))
    }
    func publicURL(_ key: String) -> URL? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: key) as? String, let url = URL(string: text), url.scheme == "https" else { return nil }
        return url
    }
}

enum AppFailure: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): text } }
}

struct SubmitPayload: Encodable, Sendable {
    var placeID: String
    var zoneID: String?
    var seat: Seat
    var noise: Noise?
    var idempotencyKey: String
    var reconfirmedAt: Date
    var location: LocationSample?
}
struct LocationSample: Encodable, Sendable {
    var latitude: Double
    var longitude: Double
    var accuracy: Double
    var sampledAt: Date
}
struct SummaryResponse: Codable, Sendable { var evidence: [Evidence] }
struct Receipt: Codable, Sendable { var id: String; var acceptedAt: Date; var nearby: Bool }

@MainActor
final class LiveService {
    let client: SupabaseClient
    private let config: AppConfiguration
    init(config: AppConfiguration) {
        self.config = config
        // This initializer is only used after configuration validation.
        client = SupabaseClient(supabaseURL: config.url ?? URL(fileURLWithPath: "/"), supabaseKey: config.key,
            options: .init(auth: .init(storage: KeychainLocalStorage(service: "app.between.auth"), emitLocalSessionAsInitialSession: true)))
    }
    func request<T: Decodable & Sendable>(_ path: String, method: String = "GET", body: Data? = nil, authenticated: Bool = false) async throws -> T {
        guard let base = config.url else { throw AppFailure.message("Add the development backend configuration to connect.") }
        var request = URLRequest(url: base.appendingPathComponent("functions/v1/between-api/" + path))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(config.key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated || client.auth.currentSession != nil {
            let session = try await client.auth.session
            request.setValue("Bearer " + session.accessToken, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw AppFailure.message("The server did not respond. Try again.") }
        if !(200..<300).contains(response.statusCode) {
            let error = try? JSONDecoder().decode(APIError.self, from: data)
            if response.statusCode == 429 {
                throw AppFailure.message("You’ve reported recently. Try again in \(error?.retryAfter ?? 300) seconds.")
            }
            throw AppFailure.message(error?.error ?? "Couldn’t complete that request. Try again.")
        }
        return try JSONDecoder.between.decode(T.self, from: data)
    }
    func summaries() async throws -> [Evidence] {
        let response: SummaryResponse = try await request("summaries")
        return response.evidence
    }
    func submit(_ payload: SubmitPayload) async throws -> Receipt {
        try await request("reports", method: "POST", body: JSONEncoder.between.encode(payload), authenticated: true)
    }
}
extension JSONDecoder {
    static var between: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid observation date"))
        }
        return decoder
    }
}
extension JSONEncoder {
    static var between: JSONEncoder { let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; return encoder }
}

struct APIError: Decodable { var error: String; var retryAfter: Int? }

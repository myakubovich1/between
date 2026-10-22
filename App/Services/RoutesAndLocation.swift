import Foundation
import MapKit
import CoreLocation
import Observation

extension Coordinate {
    var cl: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    func distance(to other: Coordinate) -> Double {
        CLLocation(latitude: latitude, longitude: longitude).distance(from: .init(latitude: other.latitude, longitude: other.longitude))
    }
}
struct RouteResult {
    var minutes: Double
    var route: MKRoute?
    var estimated: Bool
}
@MainActor
final class WalkingRoutes {
    private var cache: [String: (Date, RouteResult)] = [:]
    func route(from: Coordinate, to: Coordinate) async throws -> RouteResult {
        let key = "\(from.latitude.rounded(toPlaces: 4)),\(from.longitude.rounded(toPlaces: 4)):\(to.latitude),\(to.longitude)"
        if let (date, result) = cache[key], Date().timeIntervalSince(date) < 180 { return result }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from.cl))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to.cl))
        request.transportType = .walking
        let handle = DirectionsHandle(request: request)
        let response = try await withTaskCancellationHandler { try await handle.calculate() } onCancel: { Task { @MainActor in handle.cancel() } }
        try Task.checkCancellation()
        guard let route = response.routes.first else { throw AppFailure.message("No walking route was returned. Open Apple Maps or try another place.") }
        let result = RouteResult(minutes: route.expectedTravelTime / 60, route: route, estimated: false)
        cache[key] = (Date(), result)
        return result
    }
}
extension Double {
    func rounded(toPlaces places: Int) -> Double { let scale = pow(10.0, Double(places)); return (self * scale).rounded() / scale }
}

@MainActor @Observable
final class ForegroundLocation: NSObject, @preconcurrency CLLocationManagerDelegate {
    var message: String?
    var sample: LocationSample?
    var requesting = false
    private var manager: CLLocationManager?
    private var timeout: Task<Void, Never>?
    func request() {
        requesting = true
        message = nil
        let manager = manager ?? CLLocationManager()
        self.manager = manager
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: requesting = false; message = "Location is off. Choose a campus origin; reports can still be self-reported."
        @unknown default: requesting = false
        }
        timeout?.cancel()
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled, let self, self.requesting else { return }
            self.requesting = false
            self.message = "Couldn’t find a recent location. Choose a campus origin instead."
            self.manager?.stopUpdatingLocation()
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if requesting { request() }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        requesting = false
        timeout?.cancel()
        manager.stopUpdatingLocation()
        guard let location = locations.last, location.horizontalAccuracy >= 0, abs(location.timestamp.timeIntervalSinceNow) <= 120 else { message = "Location wasn’t recent enough. You can still use a manual origin."; return }
        sample = .init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, accuracy: location.horizontalAccuracy, sampledAt: location.timestamp)
        if location.horizontalAccuracy > 100 { message = "Approximate location. Reports will be self-reported unless a better sample is available." }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        requesting = false
        timeout?.cancel()
        manager.stopUpdatingLocation()
        message = "Location is unavailable. Choose a campus origin instead."
    }
    func clear() { sample = nil; manager?.stopUpdatingLocation() }
}

@MainActor private final class DirectionsHandle {
 let value: MKDirections
 init(request: MKDirections.Request) { value = MKDirections(request: request) }
 func calculate() async throws -> MKDirections.Response { try await value.calculate() }
 func cancel() { value.cancel() }
}

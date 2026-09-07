import CoreLocation

/// Port từ expo-location trong CheckoutScreen.tsx — xin quyền + lấy vị trí 1 lần dạng async/await
/// bọc quanh CLLocationManager delegate-based.
@MainActor
final class LocationHelper: NSObject, CLLocationManagerDelegate {
    static let shared = LocationHelper()

    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<Bool, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocation() async -> CLLocation? {
        let granted = await requestAuthorization()
        guard granted else { return nil }
        return await withCheckedContinuation { cont in
            locationContinuation = cont
            manager.requestLocation()
        }
    }

    func reverseGeocode(_ location: CLLocation) async -> String? {
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        let raw = [placemark.subThoroughfare, placemark.thoroughfare, placemark.subAdministrativeArea ?? placemark.locality, placemark.administrativeArea]
            .compactMap { $0 }
        // Vùng nông thôn đôi khi subregion/city trùng nhau, loại trùng liên tiếp — khớp bản RN cũ.
        var parts: [String] = []
        for p in raw where p != parts.last { parts.append(p) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func requestAuthorization() async -> Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return true
        case .denied, .restricted: return false
        case .notDetermined:
            return await withCheckedContinuation { cont in
                authContinuation = cont
                manager.requestWhenInUseAuthorization()
            }
        @unknown default: return false
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard let cont = authContinuation else { return }
            authContinuation = nil
            let status = manager.authorizationStatus
            cont.resume(returning: status == .authorizedWhenInUse || status == .authorizedAlways)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            locationContinuation?.resume(returning: locations.first)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }
}

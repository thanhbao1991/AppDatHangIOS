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

    /// Địa chỉ khách tự gõ tay (không chọn gợi ý/địa chỉ lưu sẵn/GPS/kéo bản đồ) — trước đây KHÔNG có
    /// toạ độ nên bị tính ship miễn phí bất kể xa gần thật, lỗ hổng thật (xem thảo luận 2026-09-12).
    /// Thử geocode xuôi khi khách rời focus ô nhập — best-effort, trả nil nếu Apple không tìm được
    /// (địa chỉ mơ hồ/thiếu thông tin), KHÔNG chặn khách đặt hàng khi thất bại.
    func geocodeAddressString(_ address: String) async -> CLLocationCoordinate2D? {
        guard let placemark = try? await CLGeocoder().geocodeAddressString(address).first,
              let location = placemark.location else { return nil }
        return location.coordinate
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
            // CLLocationManager có thể gọi callback này SỚM, ngay lúc vừa requestWhenInUseAuthorization()
            // (trước khi khách kịp bấm Cho phép/Từ chối), với status vẫn còn .notDetermined — nếu resume
            // continuation ngay lúc đó thì coi như "từ chối" oan, khách phải bấm nút thêm 1 lần nữa mới
            // thấy đúng kết quả (vì lúc đó status đã thật sự authorized, rơi vào nhánh trả về true ngay ở
            // requestAuthorization()). Bỏ qua callback này, chỉ resume khi khách đã thật sự trả lời.
            let status = manager.authorizationStatus
            guard status != .notDetermined else { return }
            guard let cont = authContinuation else { return }
            authContinuation = nil
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

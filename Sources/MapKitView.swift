import SwiftUI
import MapKit

/// Port từ MapView/Marker/Polyline (react-native-maps) trong CheckoutScreen.tsx — MKMapView thô qua
/// UIViewRepresentable thay vì Map(coordinateRegion:) cũ của SwiftUI/iOS16, vì cần ghim GIAO ĐẾN kéo
/// thả được (annotation draggable) mà API SwiftUI cũ không hỗ trợ trực tiếp.
struct DeliveryMapView: UIViewRepresentable {
    let shopCoordinate: CLLocationCoordinate2D
    var deliveryCoordinate: CLLocationCoordinate2D
    var routePoints: [CLLocationCoordinate2D]
    let onDragEnd: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)

        let shopAnn = MKPointAnnotation()
        shopAnn.coordinate = shopCoordinate
        shopAnn.title = "Đenn Coffee"
        map.addAnnotation(shopAnn)

        let deliveryAnn = DraggableAnnotation()
        deliveryAnn.coordinate = deliveryCoordinate
        deliveryAnn.title = "Giao đến đây"
        map.addAnnotation(deliveryAnn)

        let points = routePoints.count > 1 ? routePoints : [shopCoordinate, deliveryCoordinate]
        let polyline = MKPolyline(coordinates: points, count: points.count)
        map.addOverlay(polyline)

        let coords = points + [shopCoordinate, deliveryCoordinate]
        var region = MKCoordinateRegion(coordinates: coords)
        region.span.latitudeDelta = max(region.span.latitudeDelta, 0.01)
        region.span.longitudeDelta = max(region.span.longitudeDelta, 0.01)
        map.setRegion(region, animated: true)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let parent: DeliveryMapView
        init(_ parent: DeliveryMapView) { self.parent = parent }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is DraggableAnnotation else { return nil }
            let id = "delivery"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.isDraggable = true
            view.markerTintColor = UIColor(Theme.primary)
            return view
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            if newState == .ending, let coordinate = view.annotation?.coordinate {
                parent.onDragEnd(coordinate)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(Theme.primary)
            renderer.lineWidth = 3
            return renderer
        }
    }
}

private final class DraggableAnnotation: MKPointAnnotation {}

private extension MKCoordinateRegion {
    init(coordinates: [CLLocationCoordinate2D]) {
        var minLat = coordinates[0].latitude, maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude, maxLon = coordinates[0].longitude
        for c in coordinates {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.4, longitudeDelta: (maxLon - minLon) * 1.4)
        self.init(center: center, span: span)
    }
}

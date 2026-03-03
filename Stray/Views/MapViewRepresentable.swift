import SwiftUI
import MapKit

struct MapViewRepresentable: UIViewRepresentable {
    let gridEngine: GridEngine
    var showMapLabels: Bool = false
    var onCellTapped: ((GridCell) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(gridEngine: gridEngine, onCellTapped: onCellTapped)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.isPitchEnabled = false

        let config = MKStandardMapConfiguration(elevationStyle: .flat)
        if !showMapLabels {
            config.pointOfInterestFilter = .excludingAll
        }
        mapView.preferredConfiguration = config

        mapView.accessibilityLabel = "Exploration map"

        // Push the Apple legal link to be less intrusive
        mapView.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 4, right: 8)

        let fogOverlay = FogOverlay()
        mapView.addOverlay(fogOverlay, level: .aboveLabels)

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let current = gridEngine.renderGeneration
        if current != context.coordinator.lastRenderGeneration {
            context.coordinator.lastRenderGeneration = current
            context.coordinator.fogRenderer?.setNeedsDisplay()
        }

        if showMapLabels != context.coordinator.lastShowMapLabels {
            context.coordinator.lastShowMapLabels = showMapLabels
            let config = MKStandardMapConfiguration(elevationStyle: .flat)
            if !showMapLabels {
                config.pointOfInterestFilter = .excludingAll
            }
            uiView.preferredConfiguration = config
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        let gridEngine: GridEngine
        var fogRenderer: FogOverlayRenderer?
        var lastRenderGeneration: Int = 0
        var lastShowMapLabels: Bool = false
        var onCellTapped: ((GridCell) -> Void)?

        init(gridEngine: GridEngine, onCellTapped: ((GridCell) -> Void)?) {
            self.gridEngine = gridEngine
            self.onCellTapped = onCellTapped
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let fogOverlay = overlay as? FogOverlay {
                let renderer = FogOverlayRenderer(overlay: fogOverlay, gridEngine: gridEngine)
                fogRenderer = renderer
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is MKUserLocation else { return nil }
            let id = "userDot"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)

            let dotSize: CGFloat = 22
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: dotSize, height: dotSize))
            view.image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: dotSize, height: dotSize))
                UIColor.systemBlue.setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: 3, y: 3, width: dotSize - 6, height: dotSize - 6))
            }
            view.centerOffset = .zero
            view.layer.shadowColor = UIColor.systemBlue.cgColor
            view.layer.shadowRadius = 6
            view.layer.shadowOpacity = 0.4
            view.layer.shadowOffset = .zero
            return view
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {}

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let cell = GridCell.from(latitude: coordinate.latitude, longitude: coordinate.longitude)
            onCellTapped?(cell)
        }
    }
}

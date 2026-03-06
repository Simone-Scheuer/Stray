import SwiftUI
import MapKit

final class CompassTargetAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}

struct MapViewRepresentable: UIViewRepresentable {
    let gridEngine: GridEngine
    var showMapLabels: Bool = false
    var mutedMapStyle: Bool = true
    var showTraffic: Bool = false
    var showScale: Bool = true
    var allowRotation: Bool = true
    @Binding var isFollowingUser: Bool
    var onCellTapped: ((GridCell) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(gridEngine: gridEngine, onCellTapped: onCellTapped, isFollowingUser: $isFollowingUser)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = showScale
        mapView.isRotateEnabled = allowRotation

        let config = MKStandardMapConfiguration(
            emphasisStyle: mutedMapStyle ? .muted : .default
        )
        config.showsTraffic = showTraffic
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

        // Fog preload: zoom out to city scale during splash, forcing the fog renderer
        // to draw at wider zoom levels. Then zoom back to user follow mode.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let center = mapView.userLocation.coordinate.latitude != 0
                ? mapView.userLocation.coordinate
                : mapView.centerCoordinate
            let cityRegion = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
            mapView.setRegion(cityRegion, animated: false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                mapView.setUserTrackingMode(.follow, animated: false)
            }
        }

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let current = gridEngine.renderGeneration
        if current != context.coordinator.lastRenderGeneration {
            context.coordinator.lastRenderGeneration = current
            context.coordinator.fogRenderer?.setNeedsDisplay()
            context.coordinator.syncCompassTarget(on: uiView, gridEngine: gridEngine)
        }

        if isFollowingUser && uiView.userTrackingMode != .follow {
            uiView.setUserTrackingMode(.follow, animated: true)
        }

        let configChanged = showMapLabels != context.coordinator.lastShowMapLabels
            || mutedMapStyle != context.coordinator.lastMutedMapStyle
            || showTraffic != context.coordinator.lastShowTraffic
        if configChanged {
            context.coordinator.lastShowMapLabels = showMapLabels
            context.coordinator.lastMutedMapStyle = mutedMapStyle
            context.coordinator.lastShowTraffic = showTraffic
            let config = MKStandardMapConfiguration(
                emphasisStyle: mutedMapStyle ? .muted : .default
            )
            config.showsTraffic = showTraffic
            if !showMapLabels {
                config.pointOfInterestFilter = .excludingAll
            }
            uiView.preferredConfiguration = config
        }

        if showScale != context.coordinator.lastShowScale {
            context.coordinator.lastShowScale = showScale
            uiView.showsScale = showScale
        }

        if allowRotation != context.coordinator.lastAllowRotation {
            context.coordinator.lastAllowRotation = allowRotation
            uiView.isRotateEnabled = allowRotation
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        let gridEngine: GridEngine
        var fogRenderer: FogOverlayRenderer?
        var lastRenderGeneration: Int = 0
        var lastShowMapLabels: Bool = false
        var lastMutedMapStyle: Bool = true
        var lastShowTraffic: Bool = false
        var lastShowScale: Bool = true
        var lastAllowRotation: Bool = true
        var onCellTapped: ((GridCell) -> Void)?
        var compassTargetAnnotation: CompassTargetAnnotation?
        var isFollowingUser: Binding<Bool>

        init(gridEngine: GridEngine, onCellTapped: ((GridCell) -> Void)?, isFollowingUser: Binding<Bool>) {
            self.gridEngine = gridEngine
            self.onCellTapped = onCellTapped
            self.isFollowingUser = isFollowingUser
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let fogOverlay = overlay as? FogOverlay {
                let renderer = FogOverlayRenderer(overlay: fogOverlay, gridEngine: gridEngine)
                fogRenderer = renderer
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func syncCompassTarget(on mapView: MKMapView, gridEngine: GridEngine) {
            if let target = gridEngine.compassTarget {
                let coord = target.centerCoordinate
                if let existing = compassTargetAnnotation {
                    existing.coordinate = coord
                } else {
                    let ann = CompassTargetAnnotation(coordinate: coord)
                    compassTargetAnnotation = ann
                    mapView.addAnnotation(ann)
                }
            } else if let existing = compassTargetAnnotation {
                mapView.removeAnnotation(existing)
                compassTargetAnnotation = nil
            }
        }

        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            if mode == .none {
                DispatchQueue.main.async {
                    self.isFollowingUser.wrappedValue = false
                }
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is CompassTargetAnnotation {
                let id = "compassTarget"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                view.canShowCallout = false
                // Clear any recycled subviews
                view.subviews.forEach { $0.removeFromSuperview() }
                let size: CGFloat = 18
                let beacon = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                beacon.backgroundColor = UIColor.systemRed.withAlphaComponent(0.85)
                beacon.layer.cornerRadius = size / 2
                beacon.layer.borderWidth = 2
                beacon.layer.borderColor = UIColor.white.cgColor
                beacon.layer.shadowColor = UIColor.systemRed.cgColor
                beacon.layer.shadowRadius = 4
                beacon.layer.shadowOpacity = 0.8
                beacon.layer.shadowOffset = .zero
                view.addSubview(beacon)
                view.frame = beacon.frame
                view.centerOffset = .zero
                return view
            }

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

import SwiftUI
import MapKit

struct MapViewRepresentable: UIViewRepresentable {
    let gridEngine: GridEngine
    var showMapLabels: Bool = false
    var mutedMapStyle: Bool = true
    var showTraffic: Bool = false
    var allowRotation: Bool = true
    var mapStyle: String = "standard"
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
        mapView.showsScale = false
        mapView.isRotateEnabled = allowRotation
        mapView.overrideUserInterfaceStyle = .dark

        mapView.preferredConfiguration = Self.buildMapConfig(
            style: mapStyle, mutedMapStyle: mutedMapStyle,
            showTraffic: showTraffic, showMapLabels: showMapLabels
        )

        mapView.accessibilityLabel = "Exploration map"
        mapView.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 4, right: 8)

        let fogOverlay = FogOverlay()
        mapView.addOverlay(fogOverlay, level: .aboveLabels)

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        // Initial zoom: city scale during splash, then follow user
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
        }

        if isFollowingUser && uiView.userTrackingMode != .follow {
            uiView.setUserTrackingMode(.follow, animated: true)
        }

        let configChanged = showMapLabels != context.coordinator.lastShowMapLabels
            || mutedMapStyle != context.coordinator.lastMutedMapStyle
            || showTraffic != context.coordinator.lastShowTraffic
            || mapStyle != context.coordinator.lastMapStyle
        if configChanged {
            context.coordinator.lastShowMapLabels = showMapLabels
            context.coordinator.lastMutedMapStyle = mutedMapStyle
            context.coordinator.lastShowTraffic = showTraffic
            context.coordinator.lastMapStyle = mapStyle
            uiView.preferredConfiguration = Self.buildMapConfig(
                style: mapStyle, mutedMapStyle: mutedMapStyle,
                showTraffic: showTraffic, showMapLabels: showMapLabels
            )
        }

        if allowRotation != context.coordinator.lastAllowRotation {
            context.coordinator.lastAllowRotation = allowRotation
            uiView.isRotateEnabled = allowRotation
        }
    }

    static func buildMapConfig(style: String, mutedMapStyle: Bool, showTraffic: Bool, showMapLabels: Bool) -> MKMapConfiguration {
        if style == "satellite" {
            if showMapLabels {
                let config = MKHybridMapConfiguration()
                config.showsTraffic = showTraffic
                return config
            } else {
                return MKImageryMapConfiguration()
            }
        }
        let config = MKStandardMapConfiguration(
            emphasisStyle: mutedMapStyle ? .muted : .default
        )
        config.showsTraffic = showTraffic
        if !showMapLabels {
            config.pointOfInterestFilter = .excludingAll
        }
        return config
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        let gridEngine: GridEngine
        var fogRenderer: FogOverlayRenderer?
        var lastRenderGeneration: Int = 0
        var lastShowMapLabels: Bool = false
        var lastMutedMapStyle: Bool = true
        var lastShowTraffic: Bool = false
        var lastAllowRotation: Bool = true
        var lastMapStyle: String = "standard"
        var onCellTapped: ((GridCell) -> Void)?
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

        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            if mode == .none {
                DispatchQueue.main.async {
                    self.isFollowingUser.wrappedValue = false
                }
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is MKUserLocation else { return nil }
            let id = "userDot"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)

            let dotSize: CGFloat = 16
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: dotSize, height: dotSize))
            view.image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: dotSize, height: dotSize))
                UIColor.systemBlue.setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: 2.5, y: 2.5, width: dotSize - 5, height: dotSize - 5))
            }
            view.centerOffset = .zero
            view.layer.shadowColor = UIColor.systemBlue.cgColor
            view.layer.shadowRadius = 3
            view.layer.shadowOpacity = 0.3
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

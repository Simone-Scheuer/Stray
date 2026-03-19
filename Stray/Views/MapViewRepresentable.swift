import SwiftUI
import MapKit

final class CompassTargetAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}

final class RegionAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    let cellCount: Int

    init(coordinate: CLLocationCoordinate2D, cellCount: Int) {
        self.coordinate = coordinate
        self.cellCount = cellCount
    }

    var title: String? {
        "\(cellCount) cells"
    }
}

struct MapViewRepresentable: UIViewRepresentable {
    let gridEngine: GridEngine
    var showMapLabels: Bool = false
    var mutedMapStyle: Bool = true
    var showTraffic: Bool = false
    var allowRotation: Bool = true
    var mapStyle: String = "satellite"
    var colorblindMode: Bool = false
    var sessionPathPolyline: MKPolyline?
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

            if context.coordinator.lastShowRegionPins {
                context.coordinator.syncRegionPins(on: uiView, gridEngine: gridEngine, showPins: true)
            }
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

        if colorblindMode != context.coordinator.lastColorblindMode {
            context.coordinator.lastColorblindMode = colorblindMode
            context.coordinator.fogRenderer?.updateColorblindMode(colorblindMode)
            context.coordinator.fogRenderer?.setNeedsDisplay()
        }

        // Update session path polyline
        if sessionPathPolyline !== context.coordinator.currentPathPolyline {
            if let old = context.coordinator.currentPathPolyline {
                uiView.removeOverlay(old)
            }
            if let newPath = sessionPathPolyline {
                uiView.addOverlay(newPath, level: .aboveLabels)
            }
            context.coordinator.currentPathPolyline = sessionPathPolyline
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
        var lastMapStyle: String = "satellite"
        var lastColorblindMode: Bool = false
        var onCellTapped: ((GridCell) -> Void)?
        var compassTargetAnnotation: CompassTargetAnnotation?
        var regionAnnotations: [RegionAnnotation] = []
        var lastShowRegionPins: Bool = false
        var currentPathPolyline: MKPolyline?
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
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.white.withAlphaComponent(0.7)
                renderer.lineWidth = 3
                renderer.lineCap = .round
                renderer.lineJoin = .round
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

        func syncRegionPins(on mapView: MKMapView, gridEngine: GridEngine, showPins: Bool) {
            mapView.removeAnnotations(regionAnnotations)
            regionAnnotations.removeAll()

            guard showPins else {
                lastShowRegionPins = false
                return
            }

            lastShowRegionPins = true
            let summaries = gridEngine.regionSummaries()
            for summary in summaries {
                let ann = RegionAnnotation(coordinate: summary.coordinate, cellCount: summary.cellCount)
                regionAnnotations.append(ann)
            }
            mapView.addAnnotations(regionAnnotations)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let showPins = mapView.region.span.latitudeDelta > 0.5
            if showPins != lastShowRegionPins {
                syncRegionPins(on: mapView, gridEngine: gridEngine, showPins: showPins)
            }
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            if let regionAnn = annotation as? RegionAnnotation {
                mapView.deselectAnnotation(annotation, animated: false)
                let region = MKCoordinateRegion(
                    center: regionAnn.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                mapView.setRegion(region, animated: true)
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
            if let regionAnn = annotation as? RegionAnnotation {
                let id = "regionPin"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                view.canShowCallout = false

                view.subviews.forEach { $0.removeFromSuperview() }

                let countText = regionAnn.cellCount >= 1000
                    ? String(format: "%.1fk", Double(regionAnn.cellCount) / 1000.0)
                    : "\(regionAnn.cellCount)"

                let label = UILabel()
                label.text = countText
                label.font = .systemFont(ofSize: 11, weight: .bold)
                label.textColor = .white
                label.textAlignment = .center
                label.sizeToFit()

                let padding: CGFloat = 10
                let badgeWidth = max(36, label.frame.width + padding)
                let badgeHeight: CGFloat = 36

                let badge = UIView(frame: CGRect(x: 0, y: 0, width: badgeWidth, height: badgeHeight))
                badge.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.85)
                badge.layer.cornerRadius = badgeHeight / 2
                badge.layer.borderWidth = 2
                badge.layer.borderColor = UIColor.white.cgColor
                badge.layer.shadowColor = UIColor.black.cgColor
                badge.layer.shadowRadius = 3
                badge.layer.shadowOpacity = 0.3
                badge.layer.shadowOffset = CGSize(width: 0, height: 1)

                label.center = CGPoint(x: badgeWidth / 2, y: badgeHeight / 2)
                badge.addSubview(label)
                view.addSubview(badge)
                view.frame = badge.frame
                view.centerOffset = .zero
                view.displayPriority = .required
                view.zPriority = .max
                return view
            }

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
            guard !lastShowRegionPins else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let cell = GridCell.from(latitude: coordinate.latitude, longitude: coordinate.longitude)
            onCellTapped?(cell)
        }
    }
}

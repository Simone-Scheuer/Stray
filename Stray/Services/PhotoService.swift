import Foundation
import Photos
import UIKit

@MainActor
@Observable
final class PhotoService: NSObject, PHPhotoLibraryChangeObserver {
    private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    private(set) var isScanning = false
    private(set) var scanComplete = false
    private(set) var totalGeotaggedPhotos = 0

    private var index: [GridCell: [String]] = [:]
    private let imageManager = PHCachingImageManager()
    private var hasRegisteredObserver = false
    private var rescanTask: Task<Void, Never>?

    override init() {
        super.init()
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    deinit {
        // hasRegisteredObserver is always true after first scan;
        // unregister unconditionally since this is a tear-down path
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    // MARK: - Authorization

    func requestAuthorization() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.authorizationStatus = status
        if status == .authorized || status == .limited {
            registerObserverIfNeeded()
        }
        return status
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // MARK: - Scanning

    func scanLibrary() {
        guard isAuthorized, !isScanning else { return }
        isScanning = true

        Task.detached(priority: .utility) {
            var newIndex: [GridCell: [String]] = [:]
            var count = 0

            let options = PHFetchOptions()
            options.includeHiddenAssets = false
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let result = PHAsset.fetchAssets(with: .image, options: options)
            result.enumerateObjects { asset, _, _ in
                guard let location = asset.location else { return }
                let cell = GridCell.from(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                newIndex[cell, default: []].append(asset.localIdentifier)
                count += 1
            }

            await MainActor.run { [newIndex, count] in
                self.index = newIndex
                self.totalGeotaggedPhotos = count
                self.isScanning = false
                self.scanComplete = true
            }
        }

        registerObserverIfNeeded()
    }

    // MARK: - Queries

    func photoCount(for cell: GridCell) -> Int {
        index[cell]?.count ?? 0
    }

    var cellsWithPhotos: Set<GridCell> {
        Set(index.keys)
    }

    func photos(for cell: GridCell) -> PHFetchResult<PHAsset>? {
        guard let identifiers = index[cell], !identifiers.isEmpty else { return nil }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: options)
    }

    /// Returns geotagged photo assets for a specific date (yyyy-MM-dd format)
    func photosForDate(_ dateString: String) -> [PHAsset] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        guard let startOfDay = formatter.date(from: dateString) else { return [] }
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", startOfDay as NSDate, endOfDay as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            if asset.location != nil {
                assets.append(asset)
            }
        }
        return assets
    }

    // MARK: - Thumbnails

    func loadThumbnail(for asset: PHAsset, size: CGSize, completion: @escaping @MainActor (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: size.width * 2, height: size.height * 2),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            Task { @MainActor in
                completion(image)
            }
        }
    }

    // MARK: - PHPhotoLibraryChangeObserver

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            self.debouncedRescan()
        }
    }

    private func debouncedRescan() {
        rescanTask?.cancel()
        rescanTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self.scanLibrary()
        }
    }

    private func registerObserverIfNeeded() {
        guard !hasRegisteredObserver else { return }
        hasRegisteredObserver = true
        PHPhotoLibrary.shared().register(self)
    }
}

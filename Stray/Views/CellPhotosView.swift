import SwiftUI
import Photos

struct CellPhotosView: View {
    let cell: GridCell
    @Environment(\.photoService) var photoService

    @State private var assets: [PHAsset] = []
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var selectedImage: UIImage?
    @State private var showFullImage = false
    @State private var imageLoadFailed = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
    private let thumbSize = CGSize(width: 80, height: 80)

    var body: some View {
        if !photoService.isAuthorized {
            Text("Allow photo access in Settings to see photos here")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if assets.isEmpty {
            Text("No photos here")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onAppear { loadAssets() }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Photos")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(assets.prefix(9), id: \.localIdentifier) { asset in
                        thumbnailView(for: asset)
                            .onTapGesture {
                                loadFullImage(for: asset)
                            }
                    }
                }

                if assets.count > 9 {
                    Text("+\(assets.count - 9) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear { loadAssets() }
            .fullScreenCover(isPresented: $showFullImage) {
                ZStack(alignment: .topTrailing) {
                    Color.black.ignoresSafeArea()
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .ignoresSafeArea()
                    } else if imageLoadFailed {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Unable to load photo")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                    Button {
                        showFullImage = false
                        selectedImage = nil
                        imageLoadFailed = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(16)
                    }
                    .accessibilityLabel("Close preview")
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnailView(for asset: PHAsset) -> some View {
        let id = asset.localIdentifier
        if let image = thumbnails[id] {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: thumbSize.width, height: thumbSize.height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(width: thumbSize.width, height: thumbSize.height)
                .onAppear {
                    photoService.loadThumbnail(for: asset, size: thumbSize) { image in
                        if let image {
                            thumbnails[id] = image
                        }
                    }
                }
        }
    }

    private func loadAssets() {
        guard assets.isEmpty else { return }
        guard let result = photoService.photos(for: cell) else { return }
        var loaded: [PHAsset] = []
        result.enumerateObjects { asset, _, stop in
            loaded.append(asset)
            if loaded.count >= 30 { stop.pointee = true }
        }
        assets = loaded
    }

    private func loadFullImage(for asset: PHAsset) {
        selectedImage = nil
        imageLoadFailed = false
        showFullImage = true

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            Task { @MainActor in
                if let image {
                    self.selectedImage = image
                } else {
                    self.imageLoadFailed = true
                }
            }
        }
    }
}

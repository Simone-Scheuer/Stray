import SwiftUI
import Photos

struct CellPhotosView: View {
    let cell: GridCell
    @Environment(\.photoService) var photoService

    @State private var assets: [PHAsset] = []
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var selectedImage: UIImage?
    @State private var selectedAsset: PHAsset?
    @State private var selectedIndex: Int = 0
    @State private var showFullImage = false
    @State private var imageLoadFailed = false
    @State private var showShareSheet = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
    private let thumbSize = CGSize(width: 100, height: 100)

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
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 0) {
                        // Top bar — share + close
                        HStack {
                            // Photo counter
                            if assets.count > 1 {
                                Text("\(selectedIndex + 1) / \(assets.count)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                            HStack(spacing: 20) {
                                if selectedImage != nil {
                                    Button {
                                        showShareSheet = true
                                    } label: {
                                        Image(systemName: "square.and.arrow.up.circle.fill")
                                            .font(.title)
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .white.opacity(0.3))
                                    }
                                    .accessibilityLabel("Share photo")
                                }
                                Button {
                                    showFullImage = false
                                    selectedImage = nil
                                    selectedAsset = nil
                                    imageLoadFailed = false
                                    showShareSheet = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .white.opacity(0.3))
                                }
                                .accessibilityLabel("Close preview")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        Spacer()

                        // Centered photo with swipe
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.horizontal, 4)
                                .gesture(
                                    DragGesture(minimumDistance: 50)
                                        .onEnded { value in
                                            if value.translation.width < -50 {
                                                navigatePhoto(direction: 1)
                                            } else if value.translation.width > 50 {
                                                navigatePhoto(direction: -1)
                                            }
                                        }
                                )
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

                        Spacer()

                        // Metadata below photo
                        if let asset = selectedAsset {
                            VStack(spacing: 6) {
                                if let date = asset.creationDate {
                                    Text(date.formatted(date: .long, time: .omitted))
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.9))
                                    Text(date.formatted(date: .omitted, time: .shortened))
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                            .padding(.bottom, 44)
                        }
                    }
                }
                .sheet(isPresented: $showShareSheet) {
                    if let image = selectedImage {
                        ShareSheet(items: [image])
                    }
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

    private func navigatePhoto(direction: Int) {
        let newIndex = selectedIndex + direction
        guard newIndex >= 0, newIndex < assets.count else { return }
        loadFullImage(for: assets[newIndex])
    }

    private func loadFullImage(for asset: PHAsset) {
        selectedImage = nil
        selectedAsset = asset
        selectedIndex = assets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) ?? 0
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

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

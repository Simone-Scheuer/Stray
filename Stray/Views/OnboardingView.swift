import SwiftUI
import Photos

struct OnboardingView: View {
    let locationService: LocationService
    let photoService: PhotoService
    let healthService: HealthService
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var photoScanSummary: String?
    @State private var isScanning = false

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage
                .tag(0)

            locationPage
                .tag(1)

            if healthService.isAvailable {
                healthPage
                    .tag(2)
            }

            photoPage
                .tag(photoPageTag)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color.black)
        .onChange(of: locationService.authorizationStatus) { _, newStatus in
            if newStatus != .notDetermined {
                withAnimation { currentPage = 2 }
            }
        }
    }

    private var photoPageTag: Int { healthService.isAvailable ? 3 : 2 }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "map.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.9))
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text("Welcome to Stray")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Stray reveals the world as you walk through it. Dark fog covers places you haven't been. Every step uncovers a little more.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("No goals. No streaks. Just you and the map.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                withAnimation {
                    currentPage = 1
                }
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private var locationPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "location.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text("Location Access")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Stray needs your location to reveal the map as you walk. Your data stays on your device and syncs privately via iCloud.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    locationService.requestWhenInUsePermission()
                } label: {
                    Text("Allow Location Access")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    completeOnboarding()
                } label: {
                    Text("Not Now")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Health Page

    private var healthPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "heart.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text("Accurate Steps")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Stray can read your step count and walking distance from Health for more accurate stats. This is optional — we'll estimate from GPS if you skip.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        let _ = await healthService.requestAuthorization()
                        withAnimation { currentPage = photoPageTag }
                    }
                } label: {
                    Text("Allow Health Access")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    withAnimation { currentPage = photoPageTag }
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Photo Page

    private var photoPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text("Reveal Your History")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Stray can scan your photo library to reveal places you've already been. Your photos stay in your library — Stray just reads their locations.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.orange)
                        Text("Scanning photo library...")
                            .font(.callout)
                            .foregroundStyle(.orange.opacity(0.8))
                    }
                    .transition(.opacity)
                } else if let summary = photoScanSummary {
                    Text(summary)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task.detached(priority: .userInitiated) {
                        let status = await photoService.requestAuthorization()
                        if status == .authorized || status == .limited {
                            await MainActor.run { isScanning = true }
                            await photoService.scanLibrary()
                            var waited: TimeInterval = 0
                            while await !photoService.scanComplete {
                                try? await Task.sleep(for: .milliseconds(100))
                                waited += 0.1
                                if waited > 30 || Task.isCancelled { break }
                            }
                            let cells = await photoService.cellsWithPhotos.count
                            let photos = await photoService.totalGeotaggedPhotos
                            await MainActor.run {
                                isScanning = false
                                if cells > 0 {
                                    photoScanSummary = "Found \(photos) photos across \(cells) locations — your map is already coming alive."
                                } else {
                                    photoScanSummary = "No geotagged photos found. Your map starts fresh."
                                }
                            }
                            try? await Task.sleep(for: .seconds(2))
                            await MainActor.run { completeOnboarding() }
                        } else {
                            await MainActor.run { completeOnboarding() }
                        }
                    }
                } label: {
                    Text("Reveal My Map")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white.opacity(isScanning ? 0.5 : 1.0), in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isScanning)

                Button {
                    completeOnboarding()
                } label: {
                    Text("Start Fresh")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Helpers

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Constants.hasCompletedOnboardingKey)
        onComplete()
    }
}

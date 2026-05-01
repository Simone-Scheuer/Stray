import SwiftUI
import Photos

struct OnboardingView: View {
    let locationService: LocationService
    let photoService: PhotoService
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var photoScanSummary: String?
    @State private var isScanning = false

    private let amberAccent = Color(red: 0.85, green: 0.65, blue: 0.35)

    var body: some View {
        ZStack {
            StrayPalette.sheetBackground
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                locationPage.tag(1)
                photoPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
        }
        .preferredColorScheme(.dark)
        .onChange(of: locationService.authorizationStatus) { _, newStatus in
            if newStatus != .notDetermined {
                withAnimation { currentPage = 2 }
            }
        }
    }

    // MARK: - Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("stray")
                .font(.system(size: 64, weight: .regular, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.92))

            Text("LIFE CARTOGRAPHY")
                .font(.system(size: 11, weight: .medium, design: .serif))
                .tracking(2.0)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 10)

            Spacer().frame(height: 56)

            VStack(spacing: 14) {
                Text("A map of where you've been.")
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Text("Dark fog covers everywhere you haven't walked. Walking reveals the map.")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 36)

            Spacer().frame(height: 32)

            Text("No goals. No streaks. No leaderboards.")
                .font(.system(size: 13, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Spacer()

            primaryButton("continue") {
                withAnimation { currentPage = 1 }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 64)
        }
    }

    // MARK: - Location

    private var locationPage: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("LOCATION")
                .font(.system(size: 11, weight: .medium, design: .serif))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.45))

            Text("Where you walk")
                .font(.system(size: 26, weight: .regular, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            Spacer().frame(height: 36)

            Text("Stray uses your location to reveal the map as you walk. Your data stays on your device and syncs privately through iCloud.")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 36)

            Spacer()

            primaryButton("allow location") {
                locationService.requestWhenInUsePermission()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 64)
        }
    }

    // MARK: - Photos

    private var photoPage: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("PHOTOS")
                .font(.system(size: 11, weight: .medium, design: .serif))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.45))

            Text("Where you've already been")
                .font(.system(size: 26, weight: .regular, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 24)

            Spacer().frame(height: 36)

            Text("Stray can scan your photos to reveal places you've already been. Photos aren't copied; only their locations are read.")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 36)

            Spacer().frame(height: 28)

            scanStatusView
                .frame(minHeight: 28)

            Spacer()

            VStack(spacing: 18) {
                primaryButton("scan photos", isDisabled: isScanning) {
                    revealMyMap()
                }

                Button {
                    completeOnboarding()
                } label: {
                    Text("start fresh")
                        .font(.system(size: 14, weight: .regular, design: .serif).italic())
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 64)
        }
    }

    @ViewBuilder
    private var scanStatusView: some View {
        if isScanning {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(amberAccent)
                    .scaleEffect(0.8)
                Text("Scanning your library…")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(amberAccent.opacity(0.8))
            }
            .transition(.opacity)
        } else if let summary = photoScanSummary {
            Text(summary)
                .font(.system(size: 14, weight: .regular, design: .serif).italic())
                .foregroundStyle(amberAccent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .lineSpacing(2)
                .transition(.opacity)
        }
    }

    // MARK: - Components

    private func primaryButton(_ label: String, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundStyle(StrayPalette.sheetBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    amberAccent.opacity(isDisabled ? 0.4 : 1.0),
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    // MARK: - Photo scan flow

    private func revealMyMap() {
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
                    withAnimation {
                        isScanning = false
                        if cells > 0 {
                            photoScanSummary = "Found \(photos) photos across \(cells) locations."
                        } else {
                            photoScanSummary = "No geotagged photos found."
                        }
                    }
                }
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run { completeOnboarding() }
            } else {
                await MainActor.run { completeOnboarding() }
            }
        }
    }

    // MARK: - Helpers

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Constants.hasCompletedOnboardingKey)
        onComplete()
    }
}

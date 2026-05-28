import SwiftUI
import Photos

struct TimelineOverlayView: View {
    @Bindable var timelineVM: TimelineViewModel
    let onExit: () -> Void
    var onCenterCell: ((GridCell) -> Void)?

    @Environment(\.gridEngine) var gridEngine
    @Environment(\.persistenceService) var persistenceService
    @Environment(\.photoService) var photoService
    @Environment(\.pedometerService) var pedometerService

    @State private var dayPhotos: [PHAsset] = []
    @State private var pedometerDaySteps: Int?
    @State private var pedometerDayDistance: Double?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 14)

            if let day = timelineVM.selectedDay {
                let displayDistance = pedometerDayDistance ?? day.distanceMeters
                let displaySteps = pedometerDaySteps ?? day.stepCount

                HStack(alignment: .top, spacing: 28) {
                    timelineStat(value: "\(day.cellsRevealed)", label: day.cellsRevealed == 1 ? "cell" : "cells")
                    timelineStat(value: formatDistance(displayDistance), label: "walked")
                    timelineStat(value: "\(displaySteps)", label: "steps")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

                if timelineVM.dayCellCount > 0 {
                    Text("\(timelineVM.dayCellCount) visited  ·  \(timelineVM.dayNewCellCount) new")
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, 12)
                }
            }

            // Always reserve the photo-strip height so the panel sizes
            // consistently regardless of whether the day has photos.
            Group {
                if !dayPhotos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(dayPhotos, id: \.localIdentifier) { asset in
                                TimelinePhotoThumbnail(asset: asset, photoService: photoService) {
                                    if let location = asset.location {
                                        let cell = GridCell.from(
                                            latitude: location.coordinate.latitude,
                                            longitude: location.coordinate.longitude
                                        )
                                        onCenterCell?(cell)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                } else {
                    Color.clear.frame(height: 52)
                }
            }
            .padding(.bottom, 12)

            if timelineVM.activeDays.count > 1 {
                TimelineScrubber(
                    dayCount: timelineVM.activeDays.count,
                    selectedIndex: timelineVM.selectedIndex,
                    labelForIndex: { index in
                        guard index >= 0 && index < timelineVM.activeDays.count else { return "" }
                        return timelineVM.pillLabel(for: timelineVM.activeDays[index])
                    },
                    onSelect: { index in
                        guard let ps = persistenceService else { return }
                        timelineVM.selectIndex(index, gridEngine: gridEngine, persistence: ps)
                    }
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
            }
        }
        .background(StrayPalette.sheetBackground.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 20, y: 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
        .onChange(of: timelineVM.selectedIndex) { _, _ in
            loadPhotosForSelectedDay()
            refreshPedometerForDay()
        }
        .onAppear {
            loadPhotosForSelectedDay()
            refreshPedometerForDay()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Button(action: onExit) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .accessibilityLabel("Exit timeline")

            Spacer()

            HStack(spacing: 6) {
                HoldableStepButton(systemName: "chevron.left", isDisabled: !canGoBack) {
                    step(direction: -1)
                }
                .accessibilityLabel("Previous day")

                VStack(spacing: 3) {
                    Text(timelineVM.formattedDate)
                        .font(.system(size: 20, weight: .regular, design: .serif).italic())
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.75)
                    Text(timelineVM.progressLabel.uppercased())
                        .font(.system(size: 10, weight: .medium, design: .serif))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.5))
                }

                HoldableStepButton(systemName: "chevron.right", isDisabled: !canGoForward) {
                    step(direction: 1)
                }
                .accessibilityLabel("Next day")
            }

            Spacer()

            Color.clear.frame(width: 26, height: 26)
        }
    }

    private var canGoBack: Bool {
        timelineVM.selectedIndex > 0
    }

    private var canGoForward: Bool {
        timelineVM.selectedIndex < timelineVM.activeDays.count - 1
    }

    private func step(direction: Int) {
        guard let ps = persistenceService else { return }
        let newIndex = timelineVM.selectedIndex + direction
        guard newIndex >= 0 && newIndex < timelineVM.activeDays.count else { return }
        timelineVM.selectIndex(newIndex, gridEngine: gridEngine, persistence: ps)
    }

    // MARK: - Stat Component

    private func timelineStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .regular, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Helpers

    private func refreshPedometerForDay() {
        pedometerDaySteps = nil
        pedometerDayDistance = nil
        guard pedometerService.isAvailable, let day = timelineVM.selectedDay else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        guard let dayStart = formatter.date(from: day.dateString),
              let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else { return }
        Task {
            async let s = pedometerService.steps(from: dayStart, to: dayEnd)
            async let d = pedometerService.distance(from: dayStart, to: dayEnd)
            let (steps, dist) = await (s, d)
            if steps > 0 { pedometerDaySteps = steps }
            if dist > 0 { pedometerDayDistance = dist }
        }
    }

    private func loadPhotosForSelectedDay() {
        guard let day = timelineVM.selectedDay else {
            dayPhotos = []
            return
        }
        dayPhotos = photoService.photosForDate(day.dateString)
    }
}

// MARK: - Photo Thumbnail

private struct TimelinePhotoThumbnail: View {
    let asset: PHAsset
    let photoService: PhotoService
    let onTap: () -> Void

    @State private var image: UIImage?

    var body: some View {
        Button(action: onTap) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .onAppear {
            photoService.loadThumbnail(for: asset, size: CGSize(width: 52, height: 52)) { loaded in
                image = loaded
            }
        }
    }
}

// MARK: - Holdable Step Button

/// Chevron-style icon button. Tap = single action; press-and-hold = action repeats
/// after a 350ms activation delay, then every 220ms while held. Light haptic on press-down.
private struct HoldableStepButton: View {
    let systemName: String
    let isDisabled: Bool
    let action: () -> Void

    @State private var holdTimer: Timer?
    @State private var holdStarted = false

    private let holdActivationDelay: TimeInterval = 0.35
    private let holdRepeatInterval: TimeInterval = 0.22

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(.white.opacity(isDisabled ? 0.2 : 0.7))
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isDisabled, !holdStarted else { return }
                        holdStarted = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        action()
                        DispatchQueue.main.asyncAfter(deadline: .now() + holdActivationDelay) {
                            guard holdStarted else { return }
                            holdTimer = Timer.scheduledTimer(withTimeInterval: holdRepeatInterval, repeats: true) { _ in
                                action()
                            }
                        }
                    }
                    .onEnded { _ in
                        holdStarted = false
                        holdTimer?.invalidate()
                        holdTimer = nil
                    }
            )
    }
}

// MARK: - Timeline Scrubber

private struct TimelineScrubber: View {
    let dayCount: Int
    let selectedIndex: Int
    let labelForIndex: (Int) -> String
    let onSelect: (Int) -> Void

    @State private var isDragging = false
    @State private var dragIndex: Int = 0

    private let trackHeight: CGFloat = 3
    private let thumbSize: CGFloat = 18

    var body: some View {
        VStack(spacing: 8) {
            Text(labelForIndex(isDragging ? dragIndex : selectedIndex))
                .font(.system(size: 11, weight: .regular, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.65))
                .animation(.none, value: isDragging ? dragIndex : selectedIndex)

            GeometryReader { geo in
                let trackWidth = geo.size.width
                let maxIndex = max(dayCount - 1, 1)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: trackHeight)

                    let currentIndex = isDragging ? dragIndex : selectedIndex
                    let fillFraction = CGFloat(currentIndex) / CGFloat(maxIndex)
                    Capsule()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: max(trackHeight, fillFraction * trackWidth), height: trackHeight)

                    ForEach(monthTickIndices(), id: \.self) { index in
                        let x = CGFloat(index) / CGFloat(maxIndex) * trackWidth
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 3, height: 3)
                            .position(x: x, y: thumbSize / 2)
                    }

                    let thumbX = CGFloat(isDragging ? dragIndex : selectedIndex) / CGFloat(maxIndex) * trackWidth
                    Circle()
                        .fill(.white.opacity(0.92))
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                        .position(x: thumbX, y: thumbSize / 2)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let fraction = trackWidth > 0 ? max(0, min(1, value.location.x / trackWidth)) : 0
                                    let newIndex = min(Int(round(fraction * CGFloat(maxIndex))), maxIndex)
                                    dragIndex = newIndex
                                    // Don't fire onSelect during drag — only on release.
                                    // Date label updates live via dragIndex; the heavy work
                                    // (day-apply, photos, pedometer) runs once on commit.
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    onSelect(dragIndex)
                                }
                        )
                }
                .frame(height: thumbSize)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    let fraction = trackWidth > 0 ? max(0, min(1, location.x / trackWidth)) : 0
                    let index = min(Int(round(fraction * CGFloat(maxIndex))), maxIndex)
                    onSelect(index)
                }
            }
            .frame(height: thumbSize)
        }
    }

    private func monthTickIndices() -> [Int] {
        guard dayCount > 7 else { return [] }
        var ticks: [Int] = []
        var lastMonth = ""
        for i in 0..<dayCount {
            let label = labelForIndex(i)
            let month = String(label.prefix(3))
            if month != lastMonth && i > 0 {
                ticks.append(i)
            }
            lastMonth = month
        }
        return ticks
    }
}

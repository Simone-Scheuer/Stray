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
            // Header: exit + progress + date
            HStack {
                Button(action: onExit) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Exit timeline")

                Spacer()

                VStack(spacing: 2) {
                    Text(timelineVM.formattedDate)
                        .font(.headline)
                    Text(timelineVM.progressLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Spacer for symmetry with exit button
                Color.clear.frame(width: 28, height: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // Stats for selected day
            if let day = timelineVM.selectedDay {
                let displayDistance = pedometerDayDistance ?? day.distanceMeters
                let displaySteps = pedometerDaySteps ?? day.stepCount
                HStack(spacing: 20) {
                    statChip(icon: "map.fill", value: "\(day.cellsRevealed)", label: "cells")
                    statChip(icon: "figure.walk", value: formatDistance(displayDistance), label: "walked")
                    statChip(icon: "shoeprints.fill", value: "\(displaySteps)", label: "steps")
                }
                .padding(.bottom, 6)

                // Day journey highlight stats (from CellVisit journal)
                if timelineVM.dayCellCount > 0 {
                    Text("\(timelineVM.dayCellCount) visited · \(timelineVM.dayNewCellCount) new")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 10)
                }
            }

            // Photo strip for selected day
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
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 10)
            }

            // Timeline scrubber
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
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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

    private func statChip(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Label(value, systemImage: icon)
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
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
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .onAppear {
            photoService.loadThumbnail(for: asset, size: CGSize(width: 52, height: 52)) { loaded in
                image = loaded
            }
        }
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
    @State private var lastFiredIndex: Int = -1
    @State private var lastFireTime: Date = .distantPast

    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 20
    private let scrubThrottleInterval: TimeInterval = 0.1

    var body: some View {
        VStack(spacing: 6) {
            // Date label for current position
            Text(labelForIndex(isDragging ? dragIndex : selectedIndex))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .animation(.none, value: isDragging ? dragIndex : selectedIndex)

            GeometryReader { geo in
                let trackWidth = geo.size.width
                let maxIndex = max(dayCount - 1, 1)

                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: trackHeight)

                    // Filled portion
                    let currentIndex = isDragging ? dragIndex : selectedIndex
                    let fillFraction = CGFloat(currentIndex) / CGFloat(maxIndex)
                    Capsule()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: max(trackHeight, fillFraction * trackWidth), height: trackHeight)

                    // Tick marks at month boundaries
                    ForEach(monthTickIndices(), id: \.self) { index in
                        let x = CGFloat(index) / CGFloat(maxIndex) * trackWidth
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 4, height: 4)
                            .position(x: x, y: thumbSize / 2)
                    }

                    // Thumb
                    let thumbX = CGFloat(isDragging ? dragIndex : selectedIndex) / CGFloat(maxIndex) * trackWidth
                    Circle()
                        .fill(.white)
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
                                    let now = Date()
                                    if newIndex != lastFiredIndex && now.timeIntervalSince(lastFireTime) >= scrubThrottleInterval {
                                        lastFiredIndex = newIndex
                                        lastFireTime = now
                                        onSelect(newIndex)
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    if dragIndex != lastFiredIndex {
                                        lastFiredIndex = dragIndex
                                        onSelect(dragIndex)
                                    }
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

import SwiftUI
import SwiftData

struct StatsView: View {
    var onOpenTimeline: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.statsViewModel) var statsViewModel
    @Environment(\.photoService) var photoService
    @Environment(\.pedometerService) var pedometerService
    @Environment(\.dismiss) private var dismiss

    @State private var pedometerTodaySteps: Int?
    @State private var pedometerTodayDistance: Double?
    @State private var showCondensedTitle = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                journalHeader
                    .background(headerOffsetReader)
                timelineRow
                todaySection
                lifetimeSection
                citiesSection
            }
            .padding(.horizontal, 28)
            .padding(.top, 56)
            .padding(.bottom, 48)
        }
        .coordinateSpace(name: "statsScroll")
        .onPreferenceChange(ScrollOffsetKey.self) { headerMaxY in
            let shouldShow = headerMaxY < 44
            if shouldShow != showCondensedTitle {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCondensedTitle = shouldShow
                }
            }
        }
        .background(StrayPalette.sheetBackground.ignoresSafeArea())
        .overlay(alignment: .top) {
            ZStack {
                Text("your map")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.85))
                    .opacity(showCondensedTitle ? 1 : 0)

                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text("done")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 16)
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(StrayPalette.sheetBackground)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            statsViewModel.refresh(context: modelContext)
            refreshPedometerStats()
        }
    }

    // MARK: - Journal Header

    private var journalHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("your map")
                .font(.system(size: 32, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.92))
            Text(seasonalLabel)
                .font(.system(size: 11, weight: .medium, design: .serif))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.top, 8)
    }

    private var headerOffsetReader: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: ScrollOffsetKey.self,
                value: geo.frame(in: .named("statsScroll")).maxY
            )
        }
    }

    // MARK: - Timeline Row

    private var timelineRow: some View {
        Button {
            onOpenTimeline?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.55))
                Text("replay your journey")
                    .font(.system(size: 16, weight: .regular, design: .serif).italic())
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) { hairline }
            .overlay(alignment: .top) { hairline }
        }
        .disabled(onOpenTimeline == nil)
        .accessibilityLabel("Replay your journey")
    }

    // MARK: - Today

    private var todaySection: some View {
        let displayDistance = pedometerTodayDistance.map { formatDistance($0) } ?? statsViewModel.todayDistance
        let displaySteps = pedometerTodaySteps.map { formattedCount($0) } ?? statsViewModel.todaySteps
        return VStack(alignment: .leading, spacing: 18) {
            sectionHeader("today")

            HStack(alignment: .top, spacing: 24) {
                bigStat(value: "\(statsViewModel.todayCells)", label: statsViewModel.todayCells == 1 ? "new cell" : "new cells")
                bigStat(value: displayDistance, label: "walked")
                bigStat(value: displaySteps, label: "steps")
            }
        }
    }

    // MARK: - Lifetime

    private var lifetimeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("all time")

            VStack(spacing: 0) {
                lifetimeRow(value: statsViewModel.totalCells, label: "cells revealed")
                hairline
                lifetimeRow(value: statsViewModel.totalArea, label: "area explored")
                hairline
                lifetimeRow(value: statsViewModel.totalDistance, label: "distance walked")
                hairline
                lifetimeRow(value: statsViewModel.totalSteps, label: "steps")
                hairline
                lifetimeRow(value: streakText, label: "current streak")
                if photoService.isAuthorized {
                    hairline
                    lifetimeRow(value: formattedCount(photoService.totalGeotaggedPhotos), label: "geotagged photos")
                }
            }
        }
    }

    // MARK: - Cities

    private var citiesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("cities")

            if statsViewModel.cities.isEmpty {
                Text("cities will appear as you explore.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(statsViewModel.cities.enumerated()), id: \.offset) { index, entry in
                        HStack(alignment: .firstTextBaseline) {
                            Text(entry.city)
                                .font(.system(size: 18, weight: .regular, design: .serif).italic())
                                .foregroundStyle(.white.opacity(0.88))
                            Spacer()
                            Text(formattedCount(entry.count))
                                .font(.system(size: 13, weight: .regular, design: .serif).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .padding(.vertical, 12)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(entry.city), \(formattedCount(entry.count)) cells")

                        if index < statsViewModel.cities.count - 1 {
                            hairline
                        }
                    }
                }
            }
        }
    }

    // MARK: - Components

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium, design: .serif))
            .tracking(1.6)
            .foregroundStyle(.white.opacity(0.5))
    }

    private func bigStat(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 36, weight: .regular, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private func lifetimeRow(value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(value)
                .font(.system(size: 22, weight: .regular, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 13, weight: .regular, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.5)
    }

    // MARK: - Derived Values

    private var streakText: String {
        let days = statsViewModel.currentStreak
        if days == 0 { return "0 days" }
        return days == 1 ? "1 day" : "\(days) days"
    }

    private var seasonalLabel: String {
        let now = Date()
        let month = Calendar.current.component(.month, from: now)
        let year = Calendar.current.component(.year, from: now)
        let season: String
        switch month {
        case 3, 4, 5: season = "Spring"
        case 6, 7, 8: season = "Summer"
        case 9, 10, 11: season = "Autumn"
        default: season = "Winter"
        }
        return "\(season.uppercased())  ·  \(year)"
    }

    private func formattedCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private func refreshPedometerStats() {
        guard pedometerService.isAvailable else { return }
        Task {
            async let steps = pedometerService.todaySteps()
            async let dist = pedometerService.todayDistance()
            let (s, d) = await (steps, dist)
            if s > 0 { pedometerTodaySteps = s }
            if d > 0 { pedometerTodayDistance = d }
        }
    }
}

// MARK: - Stray Palette

enum StrayPalette {
    static let sheetBackground = Color(red: 0.055, green: 0.055, blue: 0.06)
}

// MARK: - Scroll Offset Tracking

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 9999
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

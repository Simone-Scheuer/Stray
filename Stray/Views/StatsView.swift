import SwiftUI
import SwiftData

struct StatsView: View {
    var onOpenTimeline: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.statsViewModel) var statsViewModel
    @Environment(\.photoService) var photoService
    @Environment(\.healthService) var healthService
    @Environment(\.dismiss) private var dismiss

    @State private var healthTodaySteps: Int?
    @State private var healthTodayDistance: Double?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    timelineSection
                    todaySection
                    lifetimeSection
                    citiesSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Your Map")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                statsViewModel.refresh(context: modelContext)
                refreshHealthStats()
            }
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        Button {
            onOpenTimeline?()
        } label: {
            HStack {
                Label("Replay your journey", systemImage: "clock.arrow.circlepath")
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .disabled(onOpenTimeline == nil)
    }

    // MARK: - Today

    private var todaySection: some View {
        let displayDistance = healthTodayDistance.map { formatDistance($0) } ?? statsViewModel.todayDistance
        let displaySteps = healthTodaySteps.map { formattedCount($0) } ?? statsViewModel.todaySteps
        return VStack(alignment: .leading, spacing: 16) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                statCard(value: "\(statsViewModel.todayCells)", label: "cells")
                Spacer()
                statCard(value: displayDistance, label: "walked")
                Spacer()
                statCard(value: displaySteps, label: "steps")
            }
        }
    }

    // MARK: - Lifetime

    private var lifetimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Time")
                .font(.headline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                lifetimeCard(value: statsViewModel.totalCells, label: "cells revealed")
                lifetimeCard(value: statsViewModel.totalDistance, label: "distance")
                lifetimeCard(value: statsViewModel.totalSteps, label: "steps")
                lifetimeCard(value: streakText, label: "streak")
                lifetimeCard(value: statsViewModel.totalArea, label: "area explored")
                if photoService.isAuthorized {
                    lifetimeCard(value: formattedCount(photoService.totalGeotaggedPhotos), label: "geotagged photos")
                }
            }
        }
    }

    // MARK: - Cities

    private var citiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cities")
                .font(.headline)
                .foregroundStyle(.secondary)

            if statsViewModel.cities.isEmpty {
                Text("Cities will appear as you explore.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(statsViewModel.cities.enumerated()), id: \.offset) { index, entry in
                        HStack {
                            Text(entry.city)
                                .font(.body)
                            Spacer()
                            Text(formattedCount(entry.count))
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(entry.city), \(formattedCount(entry.count)) cells")

                        if index < statsViewModel.cities.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Components

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label) today")
    }

    private func lifetimeCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private var streakText: String {
        let days = statsViewModel.currentStreak
        if days == 0 { return "0 days" }
        return days == 1 ? "1 day" : "\(days) days"
    }

    private func formattedCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private func refreshHealthStats() {
        guard healthService.isAuthorized else { return }
        Task {
            async let steps = healthService.todaySteps()
            async let dist = healthService.todayDistance()
            let (s, d) = await (steps, dist)
            healthTodaySteps = s
            healthTodayDistance = d
        }
    }
}

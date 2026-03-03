import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.statsViewModel) var statsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    todaySection
                    lifetimeSection
                    sessionsSection
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
            }
        }
    }

    // MARK: - Today

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                statCard(value: "\(statsViewModel.todayCells)", label: "cells")
                Spacer()
                statCard(value: statsViewModel.todayDistance, label: "walked")
                Spacer()
                statCard(value: statsViewModel.todaySteps, label: "steps")
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
            }
        }
    }

    // MARK: - Sessions

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stray Sessions")
                .font(.headline)
                .foregroundStyle(.secondary)

            if statsViewModel.sessionCount == 0 {
                Text("Start a Stray session to see your exploration stats here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                HStack {
                    Text("\(statsViewModel.sessionCount)")
                        .font(.title2.bold())
                    Text(statsViewModel.sessionCount == 1 ? "session" : "sessions")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(statsViewModel.sessionCount) \(statsViewModel.sessionCount == 1 ? "session" : "sessions")")
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
}

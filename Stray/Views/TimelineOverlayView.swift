import SwiftUI

struct TimelineOverlayView: View {
    @Bindable var timelineVM: TimelineViewModel
    let onExit: () -> Void

    @Environment(\.gridEngine) var gridEngine
    @Environment(\.persistenceService) var persistenceService

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

                // Prev/Next nav
                HStack(spacing: 16) {
                    Button {
                        guard let ps = persistenceService else { return }
                        timelineVM.goBack(gridEngine: gridEngine, persistence: ps)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                    }
                    .disabled(!timelineVM.canGoBack)

                    Button {
                        guard let ps = persistenceService else { return }
                        timelineVM.goForward(gridEngine: gridEngine, persistence: ps)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                    }
                    .disabled(!timelineVM.canGoForward)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // Stats for selected day
            if let day = timelineVM.selectedDay {
                HStack(spacing: 20) {
                    statChip(icon: "map.fill", value: "\(day.cellsRevealed)", label: "cells")
                    statChip(icon: "figure.walk", value: formatDistance(day.distanceMeters), label: "walked")
                    statChip(icon: "shoeprints.fill", value: "\(day.stepCount)", label: "steps")
                }
                .padding(.bottom, 14)
            }

            // Day pill scrubber
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(timelineVM.activeDays.enumerated()), id: \.offset) { index, day in
                            let isSelected = index == timelineVM.selectedIndex
                            Button {
                                guard let ps = persistenceService else { return }
                                timelineVM.selectIndex(index, gridEngine: gridEngine, persistence: ps)
                            } label: {
                                Text(timelineVM.pillLabel(for: day))
                                    .font(.caption.weight(isSelected ? .semibold : .regular))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                                    .foregroundStyle(isSelected ? .white : .secondary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().strokeBorder(
                                            isSelected ? Color.white.opacity(0.5) : .clear,
                                            lineWidth: 1
                                        )
                                    )
                            }
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .onChange(of: timelineVM.selectedIndex) { _, newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
        .gesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .local)
                .onEnded { value in
                    guard let ps = persistenceService else { return }
                    if value.translation.width < -40 {
                        timelineVM.goForward(gridEngine: gridEngine, persistence: ps)
                    } else if value.translation.width > 40 {
                        timelineVM.goBack(gridEngine: gridEngine, persistence: ps)
                    }
                }
        )
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

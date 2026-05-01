import SwiftUI

struct CellInspectorView: View {
    let cell: GridCell
    @Environment(\.gridEngine) var gridEngine
    @Environment(\.persistenceService) var persistenceService
    @Environment(\.dismiss) var dismiss

    @State private var showMarkOptions = false
    @State private var showRemoveAlert = false
    @State private var customLabel = ""
    @State private var cellNotes = ""
    @FocusState private var isNotesFieldFocused: Bool

    private let amberAccent = Color(red: 0.85, green: 0.65, blue: 0.35)

    var body: some View {
        let count = gridEngine.visitCount(for: cell)
        let specialTile = gridEngine.specialTile(for: cell)
        let record = persistenceService?.fetchCell(key: cell.key)

        VStack(alignment: .leading, spacing: 0) {
            header(count: count, specialTile: specialTile, record: record)
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryText(count: count, record: record)
                        .padding(.horizontal, 24)

                    if count > 0 {
                        hairline.padding(.horizontal, 24)
                        CellPhotosView(cell: cell)
                            .padding(.horizontal, 24)
                    }

                    if count > 0 {
                        hairline.padding(.horizontal, 24)
                        notesField
                            .padding(.horizontal, 24)
                    }

                    if count > 0 {
                        hairline.padding(.horizontal, 24)
                        actionsArea(specialTile: specialTile)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                    }
                }
            }
        }
        .background(StrayPalette.sheetBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            if let record = persistenceService?.fetchCell(key: cell.key) {
                cellNotes = record.notes
            }
        }
        .onChange(of: isNotesFieldFocused) { _, focused in
            if !focused {
                saveNotesIfNeeded()
            }
        }
        .alert("Remove Marker?", isPresented: $showRemoveAlert) {
            Button("Remove", role: .destructive) { removeMarker() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The tile stays revealed.")
        }
    }

    // MARK: - Header

    private func header(count: Int, specialTile: SpecialTile?, record: RevealedCell?) -> some View {
        HStack(alignment: .top) {
            Text(titleString(count: count, specialTile: specialTile, record: record))
                .font(.system(size: 11, weight: .medium, design: .serif))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(2)

            Spacer()

            Button {
                saveNotesIfNeeded()
                gridEngine.setInspectedCell(nil)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .accessibilityLabel("Close inspector")
        }
    }

    private func titleString(count: Int, specialTile: SpecialTile?, record: RevealedCell?) -> String {
        var parts: [String] = []
        if let city = record?.city { parts.append(city) }
        if let label = specialTile?.label { parts.append(label) }
        if parts.isEmpty {
            parts.append(count > 0 ? "Explored" : "Unexplored")
        }
        return parts.joined(separator: "  ·  ").uppercased()
    }

    // MARK: - Summary

    private func summaryText(count: Int, record: RevealedCell?) -> some View {
        Text(literarySummary(count: count, record: record))
            .font(.system(size: 19, weight: .regular, design: .serif).italic())
            .foregroundStyle(.white.opacity(0.88))
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func literarySummary(count: Int, record: RevealedCell?) -> String {
        guard count > 0 else {
            return "Walk through this area to reveal it."
        }
        guard let record = record else {
            return "You've passed through here \(describeCount(count))."
        }
        let firstFormatted = formatOrdinalDate(record.firstVisitedAt)
        let lastRelative = relativeTime(from: record.lastVisitedAt)
        if count == 1 {
            return "You first walked here \(lastRelative)."
        }
        return "You've passed through here \(describeCount(count)) since \(firstFormatted), most recently \(lastRelative)."
    }

    private func describeCount(_ n: Int) -> String {
        if n == 1 { return "once" }
        if n == 2 { return "twice" }
        if n < 10 {
            let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
            return "\(words[n]) times"
        }
        return "\(n) times"
    }

    private func formatOrdinalDate(_ date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        let month = date.formatted(.dateTime.month(.wide))
        let year = Calendar.current.component(.year, from: date)
        let nowYear = Calendar.current.component(.year, from: Date())
        let ordinalFormatter = NumberFormatter()
        ordinalFormatter.numberStyle = .ordinal
        let ordinalDay = ordinalFormatter.string(from: NSNumber(value: day)) ?? "\(day)"
        if year == nowYear {
            return "the \(ordinalDay) of \(month)"
        }
        return "the \(ordinalDay) of \(month), \(year)"
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Notes

    private var notesField: some View {
        TextField(
            "",
            text: $cellNotes,
            prompt: Text("add a note about this place…")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundColor(.white.opacity(0.35)),
            axis: .vertical
        )
        .lineLimit(3...6)
        .textFieldStyle(.plain)
        .font(.system(size: 15, weight: .regular, design: .serif).italic())
        .foregroundStyle(.white.opacity(0.85))
        .focused($isNotesFieldFocused)
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionsArea(specialTile: SpecialTile?) -> some View {
        if specialTile != nil {
            Button {
                showRemoveAlert = true
            } label: {
                Text("remove marker")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(Color.red.opacity(0.78))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            .accessibilityLabel("Remove tile marker")
        } else if showMarkOptions {
            markOptionsView
        } else {
            Button {
                showMarkOptions = true
            } label: {
                Text("mark this tile")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(amberAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            .accessibilityLabel("Mark this tile as a special location")
        }
    }

    private var markOptionsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CHOOSE A MARKER")
                .font(.system(size: 10, weight: .medium, design: .serif))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.5))

            VStack(spacing: 0) {
                ForEach(Array(Constants.specialTilePresets.enumerated()), id: \.offset) { index, preset in
                    Button {
                        markTile(label: preset.label, icon: preset.icon, colorHex: preset.colorHex)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: preset.icon)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color(uiColor: UIColor(hex: preset.colorHex) ?? .white))
                                .frame(width: 18)
                            Text(preset.label.lowercased())
                                .font(.system(size: 16, weight: .regular, design: .serif))
                                .foregroundStyle(.white.opacity(0.88))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    if index < Constants.specialTilePresets.count - 1 {
                        hairline
                    }
                }
            }

            HStack(spacing: 10) {
                TextField(
                    "",
                    text: $customLabel,
                    prompt: Text("custom label…")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundColor(.white.opacity(0.35))
                )
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

                Button {
                    let label = customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !label.isEmpty else { return }
                    markTile(label: label, icon: "mappin", colorHex: "#FF6B6B")
                } label: {
                    Text("add")
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .foregroundStyle(amberAccent.opacity(customLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1.0))
                }
                .disabled(customLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Components

    private var hairline: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.5)
    }

    // MARK: - Persistence

    private func markTile(label: String, icon: String, colorHex: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        persistenceService?.saveSpecialTile(for: cell, label: label, icon: icon, colorHex: colorHex)
        let tile = persistenceService?.fetchSpecialTile(for: cell)
        gridEngine.setSpecialTile(tile, for: cell)
        showMarkOptions = false
        customLabel = ""
    }

    private func removeMarker() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        persistenceService?.deleteSpecialTile(for: cell)
        gridEngine.setSpecialTile(nil, for: cell)
    }

    private func saveNotesIfNeeded() {
        let trimmed = cellNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let record = persistenceService?.fetchCell(key: cell.key), record.notes != trimmed {
            persistenceService?.updateCellNotes(cell, notes: trimmed)
        }
    }
}

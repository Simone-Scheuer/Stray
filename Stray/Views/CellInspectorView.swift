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

    var body: some View {
        let count = gridEngine.visitCount(for: cell)
        let specialTile = gridEngine.specialTile(for: cell)

        VStack(alignment: .leading, spacing: 0) {
            // Header (pinned, never scrolls)
            HStack {
                if let special = specialTile {
                    Label(special.label, systemImage: special.icon)
                        .font(.headline)
                        .foregroundStyle(Color(uiColor: UIColor(hex: special.colorHex) ?? .white))
                } else {
                    Text(count > 0 ? "Explored" : "Unexplored")
                        .font(.headline)
                }
                Spacer()
                Button {
                    saveNotesIfNeeded()
                    gridEngine.setInspectedCell(nil)
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close inspector")
            }
            .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

            // Photos (top billing — "the star of the show")
            if count > 0 {
                CellPhotosView(cell: cell)
                Divider()
            }

            // Visit details
            if count > 0, let record = persistenceService?.fetchCell(key: cell.key) {
                if let city = record.city {
                    LabeledContent("City", value: city)
                        .accessibilityLabel("City: \(city)")
                }
                LabeledContent("Visits", value: "\(record.visitCount)")
                    .accessibilityLabel("\(record.visitCount) visits")
                LabeledContent("First visited", value: record.firstVisitedAt.formatted(date: .abbreviated, time: .shortened))
                    .accessibilityLabel("First visited \(record.firstVisitedAt.formatted(date: .abbreviated, time: .shortened))")
                LabeledContent("Last visited", value: record.lastVisitedAt.formatted(date: .abbreviated, time: .shortened))
                    .accessibilityLabel("Last visited \(record.lastVisitedAt.formatted(date: .abbreviated, time: .shortened))")
            } else if count > 0 {
                LabeledContent("Visits", value: "\(count)")
                    .accessibilityLabel("\(count) visits")
            } else {
                Text("Walk through this area to reveal it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Notes (for explored cells)
            if count > 0 {
                Divider()
                TextField("Add a note...", text: $cellNotes, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .focused($isNotesFieldFocused)
            }

            // Mark/unmark controls (only for explored cells)
            if count > 0 {
                Divider()

                if specialTile != nil {
                    Button(role: .destructive) {
                        showRemoveAlert = true
                    } label: {
                        Label("Remove Marker", systemImage: "xmark.circle")
                    }
                    .accessibilityLabel("Remove tile marker")
                } else if showMarkOptions {
                    markOptionsView
                } else {
                    Button {
                        showMarkOptions = true
                    } label: {
                        Label("Mark This Tile", systemImage: "mappin.and.ellipse")
                    }
                    .accessibilityLabel("Mark this tile as a special location")
                }
            } // if count > 0 (mark controls)
                } // VStack inside ScrollView
            } // ScrollView
        } // outer VStack
        .padding()
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
            Text("This will remove the marker from this tile.")
        }
    }

    // MARK: - Mark Options

    private var markOptionsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose a marker")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Presets
            ForEach(Constants.specialTilePresets, id: \.label) { preset in
                Button {
                    markTile(label: preset.label, icon: preset.icon, colorHex: preset.colorHex)
                } label: {
                    Label(preset.label, systemImage: preset.icon)
                        .foregroundStyle(Color(uiColor: UIColor(hex: preset.colorHex) ?? .white))
                }
            }

            // Custom
            HStack {
                TextField("Custom label", text: $customLabel)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let label = customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !label.isEmpty else { return }
                    markTile(label: label, icon: "mappin", colorHex: "#FF6B6B")
                }
                .disabled(customLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: - Actions

    private func markTile(label: String, icon: String, colorHex: String) {
        persistenceService?.saveSpecialTile(for: cell, label: label, icon: icon, colorHex: colorHex)
        let tile = persistenceService?.fetchSpecialTile(for: cell)
        gridEngine.setSpecialTile(tile, for: cell)
        showMarkOptions = false
        customLabel = ""
    }

    private func removeMarker() {
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

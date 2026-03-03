import SwiftUI

struct CellInspectorView: View {
    let cell: GridCell
    @Environment(\.gridEngine) var gridEngine
    @Environment(\.persistenceService) var persistenceService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        let count = gridEngine.visitCount(for: cell)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(count > 0 ? "Explored" : "Unexplored")
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close inspector")
            }

            if count > 0, let record = persistenceService?.fetchCell(key: cell.key) {
                LabeledContent("Visits", value: "\(record.visitCount)")
                    .accessibilityLabel("\(record.visitCount) visits")
                LabeledContent("First visited", value: record.firstVisitedAt.formatted(date: .abbreviated, time: .shortened))
                    .accessibilityLabel("First visited \(record.firstVisitedAt.formatted(date: .abbreviated, time: .shortened))")
                LabeledContent("Last visited", value: record.lastVisitedAt.formatted(date: .abbreviated, time: .shortened))
                    .accessibilityLabel("Last visited \(record.lastVisitedAt.formatted(date: .abbreviated, time: .shortened))")
                if let city = record.city {
                    LabeledContent("City", value: city)
                        .accessibilityLabel("City: \(city)")
                } else {
                    LabeledContent("City") {
                        Text("Locating...")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("City: locating")
                }
            } else if count > 0 {
                LabeledContent("Visits", value: "\(count)")
                    .accessibilityLabel("\(count) visits")
            } else {
                Text("Walk through this area to reveal it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

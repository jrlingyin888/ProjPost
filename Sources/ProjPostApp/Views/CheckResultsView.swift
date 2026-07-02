import ProjPostCore
import SwiftUI

struct CheckResultsView: View {
    let results: [CheckResult]

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if results.isEmpty {
                    Text("No checks run yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(results) { result in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: symbol(for: result.severity))
                                .foregroundStyle(color(for: result.severity))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.headline)
                                Text(result.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Configuration Checks", systemImage: "checklist")
        }
    }

    private func symbol(for severity: CheckSeverity) -> String {
        switch severity {
        case .green:
            return "checkmark.circle.fill"
        case .yellow:
            return "exclamationmark.triangle.fill"
        case .red:
            return "xmark.octagon.fill"
        }
    }

    private func color(for severity: CheckSeverity) -> Color {
        switch severity {
        case .green:
            return .green
        case .yellow:
            return .yellow
        case .red:
            return .red
        }
    }
}

import ProjPostCore
import SwiftUI

struct UploadProgressView: View {
    let state: UploadJobState
    let events: [UploadEvent]
    @EnvironmentObject private var localizationStore: LocalizationStore

    private var strings: AppStrings {
        AppStrings(language: localizationStore.language)
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label(stateText, systemImage: stateSymbol)
                    .font(.headline)

                if events.isEmpty {
                    Text(strings.noUploadEvents)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: event.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .foregroundStyle(event.succeeded ? .green : .red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(strings.uploadStep(event.step))
                                    .font(.subheadline.weight(.medium))
                                Text(event.message)
                                    .font(.system(.caption, design: .monospaced))
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
            Label(strings.uploadConsole, systemImage: "terminal")
        }
    }

    private var stateText: String {
        switch state {
        case .idle:
            return strings.idle
        case .running(let step):
            return strings.runningUploadStep(step)
        case .succeeded(let message):
            return message
        case .failed(let message):
            return message
        case .cancelled:
            return strings.cancelled
        }
    }

    private var stateSymbol: String {
        switch state {
        case .idle:
            return "pause.circle"
        case .running:
            return "arrow.triangle.2.circlepath.circle"
        case .succeeded:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.octagon.fill"
        case .cancelled:
            return "nosign"
        }
    }
}

import ProjPostCore
import SwiftUI

struct ConsolePane: View {
    let entries: [ActivityEntry]
    @Binding var isCollapsed: Bool
    let onClear: () -> Void
    @EnvironmentObject private var localizationStore: LocalizationStore

    private var strings: AppStrings { AppStrings(language: localizationStore.language) }

    var body: some View {
        VStack(spacing: 0) {
            header
            if !isCollapsed {
                Divider()
                logList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label(strings.activityConsole, systemImage: "terminal")
                .font(.callout.weight(.semibold))
            if isCollapsed, let last = entries.last {
                Text(last.message).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button(strings.clearLog) { onClear() }
                .buttonStyle(.borderless).font(.caption).disabled(entries.isEmpty)
            Button { isCollapsed.toggle() } label: {
                Image(systemName: isCollapsed ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if entries.isEmpty {
                        Text(strings.noActivityYet).font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                    } else {
                        ForEach(entries) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.timestamp, format: .dateTime.hour().minute().second())
                                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
                                Image(systemName: glyph(entry.level)).foregroundStyle(color(entry.level)).font(.caption2)
                                Text(entry.message).font(.caption.monospaced())
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .id(entry.id)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 180)
            .onChange(of: entries.count) { _ in
                if let last = entries.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    private func glyph(_ level: ActivityLevel) -> String {
        switch level {
        case .info: return "circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private func color(_ level: ActivityLevel) -> Color {
        switch level {
        case .info: return .secondary
        case .success: return .green
        case .error: return .red
        }
    }
}

import AppKit
import ProjPostCore
import SwiftUI

struct AppleAccountGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    linkRow
                    ForEach(AppleAccountGuideContent.sections) { section in
                        guideSection(section)
                    }
                    ForEach(AppleAccountGuideContent.screenshots) { screenshot in
                        guideScreenshot(screenshot)
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 760, idealWidth: 860, minHeight: 620, idealHeight: 720)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Account Guide")
                    .font(.title2.weight(.semibold))
                Text("Find the .p8 key, Key ID, Issuer ID, and Team ID for JJPost.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }

    private var linkRow: some View {
        HStack(spacing: 12) {
            Link("Open App Store Connect API", destination: AppleAccountGuideContent.appStoreConnectURL)
            Link("Open Apple Developer Account", destination: AppleAccountGuideContent.developerMembershipURL)
            Spacer()
        }
        .buttonStyle(.bordered)
    }

    private func guideSection(_ section: AppleAccountGuideSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.headline)
            ForEach(Array(section.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                    Text(step)
                        .font(.callout)
                }
            }
        }
    }

    private func guideScreenshot(_ screenshot: AppleAccountGuideScreenshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(screenshot.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let image = loadImage(screenshot) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.quaternary)
                    )
            } else {
                Label("Screenshot resource missing: \(screenshot.resourceName)", systemImage: "photo")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func loadImage(_ screenshot: AppleAccountGuideScreenshot) -> NSImage? {
        guard let url = Bundle.module.url(
            forResource: screenshot.resourceName,
            withExtension: "png",
            subdirectory: screenshot.subdirectory
        ) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

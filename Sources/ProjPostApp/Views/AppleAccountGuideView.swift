import AppKit
import ProjPostCore
import SwiftUI

struct AppleAccountGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var language = AppleAccountGuideContent.defaultLanguage
    @State private var previewedScreenshot: AppleAccountGuideScreenshot?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    linkRow
                    ForEach(AppleAccountGuideContent.sections(for: language)) { section in
                        guideSection(section)
                    }
                    ForEach(AppleAccountGuideContent.screenshots(for: language)) { screenshot in
                        guideScreenshot(screenshot)
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 760, idealWidth: 860, minHeight: 620, idealHeight: 720)
        .sheet(item: $previewedScreenshot) { screenshot in
            screenshotPreview(screenshot)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppleAccountGuideContent.title(for: language))
                    .font(.title2.weight(.semibold))
                Text(AppleAccountGuideContent.subtitle(for: language))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Language", selection: $language) {
                ForEach(AppleAccountGuideLanguage.allCases) { option in
                    Text(AppleAccountGuideContent.languageDisplayName(option))
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 160)

            Button(AppleAccountGuideContent.doneButtonTitle(for: language)) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }

    private var linkRow: some View {
        HStack(spacing: 12) {
            Link(AppleAccountGuideContent.appStoreConnectLinkTitle(for: language), destination: AppleAccountGuideContent.appStoreConnectURL)
            Link(AppleAccountGuideContent.developerAccountLinkTitle(for: language), destination: AppleAccountGuideContent.developerMembershipURL)
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
                Button {
                    previewedScreenshot = screenshot
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(.quaternary)
                            )
                        Label(AppleAccountGuideContent.openImageTitle(for: language), systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Label("Screenshot resource missing: \(screenshot.resourceName)", systemImage: "photo")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func loadImage(_ screenshot: AppleAccountGuideScreenshot) -> NSImage? {
        let url = Bundle.module.url(
            forResource: screenshot.resourceName,
            withExtension: "png",
            subdirectory: screenshot.subdirectory
        ) ?? Bundle.module.url(
            forResource: screenshot.resourceName,
            withExtension: "png"
        )
        guard let url else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private func screenshotPreview(_ screenshot: AppleAccountGuideScreenshot) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(screenshot.caption)
                    .font(.headline)
                Spacer()
                Button(AppleAccountGuideContent.doneButtonTitle(for: language)) {
                    previewedScreenshot = nil
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            Divider()
            ScrollView([.horizontal, .vertical]) {
                if let image = loadImage(screenshot) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 1200, maxHeight: 760)
                        .padding(20)
                } else {
                    Label("Screenshot resource missing: \(screenshot.resourceName)", systemImage: "photo")
                        .foregroundStyle(.orange)
                        .padding(40)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 620)
    }
}

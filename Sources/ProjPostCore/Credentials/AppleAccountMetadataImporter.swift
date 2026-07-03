import AppKit
import Foundation

public struct AppleAccountMetadata: Equatable {
    public var keyID: String
    public var issuerID: String
    public var teamID: String?

    public init(keyID: String, issuerID: String, teamID: String?) {
        self.keyID = keyID
        self.issuerID = issuerID
        self.teamID = teamID
    }
}

public enum AppleAccountMetadataImporterError: Error, Equatable {
    case unreadableTextFile(URL)
    case missingRequiredFields([String])
}

public final class AppleAccountMetadataImporter {
    public init() {}

    public func importMetadata(from url: URL) throws -> AppleAccountMetadata {
        let data = try Data(contentsOf: url)
        let text: String
        if url.pathExtension.lowercased() == "rtf" {
            text = try Self.rtfPlainText(from: data)
        } else if let decoded = Self.decodePlainText(data) {
            text = decoded
        } else {
            throw AppleAccountMetadataImporterError.unreadableTextFile(url)
        }

        return try Self.parse(text)
    }

    public static func parse(_ text: String) throws -> AppleAccountMetadata {
        let keyID = firstValue(in: text, labelPattern: #"(?:api\s+)?key\s*id"#)
        let issuerID = firstValue(in: text, labelPattern: #"issuer\s*id"#)
        let teamID = firstValue(in: text, labelPattern: #"team\s*id"#)
        var missing: [String] = []
        if keyID == nil { missing.append("Key ID") }
        if issuerID == nil { missing.append("Issuer ID") }
        guard let keyID, let issuerID else {
            throw AppleAccountMetadataImporterError.missingRequiredFields(missing)
        }

        return AppleAccountMetadata(keyID: keyID, issuerID: issuerID, teamID: teamID)
    }

    private static func firstValue(in text: String, labelPattern: String) -> String? {
        let pattern = #"(?im)^\s*\#(labelPattern)\s*[:：=]\s*([A-Za-z0-9._-]+)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else { return nil }
        guard let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodePlainText(_ data: Data) -> String? {
        for encoding in [String.Encoding.utf8, .utf16, .ascii] {
            if let decoded = String(data: data, encoding: encoding) {
                return decoded
            }
        }
        return nil
    }

    private static func rtfPlainText(from data: Data) throws -> String {
        let attributed = try NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
        return attributed.string
    }
}

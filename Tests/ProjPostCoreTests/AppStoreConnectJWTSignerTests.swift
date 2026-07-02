import XCTest
import Crypto
@testable import ProjPostCore

final class AppStoreConnectJWTSignerTests: XCTestCase {
    func testJWTContainsExpectedHeaderAndPayloadFieldsAndValidSignature() throws {
        let privateKey = P256.Signing.PrivateKey()
        let pem = privateKey.pemRepresentation
        let account = AppleAccountProfile(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            displayName: "Company",
            keyID: "ABC123DEF4",
            issuerID: "69a6de7f-1111-2222-3333-444444444444",
            teamID: nil,
            lastVerifiedAt: nil
        )

        let jwt = try AppStoreConnectJWTSigner().makeJWT(
            account: account,
            privateKeyPEM: pem,
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let parts = jwt.split(separator: ".").map(String.init)
        XCTAssertEqual(parts.count, 3)

        let header = try XCTUnwrap(Self.decodeJSONPart(parts[0]))
        let payload = try XCTUnwrap(Self.decodeJSONPart(parts[1]))

        XCTAssertEqual(header["alg"] as? String, "ES256")
        XCTAssertEqual(header["kid"] as? String, "ABC123DEF4")
        XCTAssertEqual(header["typ"] as? String, "JWT")
        XCTAssertEqual(payload["iss"] as? String, "69a6de7f-1111-2222-3333-444444444444")
        XCTAssertEqual(payload["aud"] as? String, "appstoreconnect-v1")
        XCTAssertEqual((payload["iat"] as? NSNumber)?.intValue, 1_700_000_000)
        XCTAssertEqual((payload["exp"] as? NSNumber)?.intValue, 1_700_001_200)

        let signatureData = try XCTUnwrap(Self.decodeBase64URL(parts[2]))
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: signatureData)
        let signedData = Data("\(parts[0]).\(parts[1])".utf8)

        XCTAssertTrue(privateKey.publicKey.isValidSignature(signature, for: signedData))
    }

    private static func decodeJSONPart(_ text: String) throws -> [String: Any]? {
        let data = try XCTUnwrap(decodeBase64URL(text))
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func decodeBase64URL(_ text: String) throws -> Data? {
        var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        return try XCTUnwrap(Data(base64Encoded: base64))
    }
}

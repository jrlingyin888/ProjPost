import Crypto
import Foundation

public struct AppStoreConnectJWTSigner {
    public init() {}

    public func makeJWT(account: AppleAccountProfile, privateKeyPEM: String, issuedAt: Date = Date()) throws -> String {
        let issued = Int(issuedAt.timeIntervalSince1970)
        let header: [String: Any] = [
            "alg": "ES256",
            "kid": account.keyID,
            "typ": "JWT"
        ]
        let payload: [String: Any] = [
            "iss": account.issuerID,
            "iat": issued,
            "exp": issued + 20 * 60,
            "aud": "appstoreconnect-v1"
        ]

        let headerPart = try Self.base64URLJSON(header)
        let payloadPart = try Self.base64URLJSON(payload)
        let signingInput = "\(headerPart).\(payloadPart)"

        let key = try P256.Signing.PrivateKey(pemRepresentation: privateKeyPEM)
        let signature = try key.signature(for: Data(signingInput.utf8))

        return "\(signingInput).\(Self.base64URL(signature.rawRepresentation))"
    }

    private static func base64URLJSON(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return base64URL(data)
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

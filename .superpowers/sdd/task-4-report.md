# Task 4 Report (2026-07-02)

## Implemented
- Added `Sources/ProjPostCore/Credentials/CredentialVault.swift` with:
  - `CredentialVault` protocol
  - `CredentialVaultError` enum
  - `KeychainCredentialVault` for local Keychain-backed storage
  - save, fetch, and delete operations keyed by `UUID`
- Added `Sources/ProjPostCore/AppStoreConnect/AppStoreConnectJWTSigner.swift` with:
  - `AppStoreConnectJWTSigner.makeJWT(account:privateKeyPEM:issuedAt:)`
  - ES256 signing using `swift-crypto`
  - base64url JWT assembly with header, payload, and raw ECDSA signature
- Added `Tests/ProjPostCoreTests/AppStoreConnectJWTSignerTests.swift` covering:
  - JWT header fields
  - JWT payload fields
  - deterministic issued-at input for the test case

## Validation
- Red test:
  - `swift test --filter AppStoreConnectJWTSignerTests`
  - Failed as expected before implementation with `cannot find 'AppStoreConnectJWTSigner' in scope`
- Focused green run:
  - `swift test --filter AppStoreConnectJWTSignerTests`
  - Passed: 1 test, 0 failures
- Full suite:
  - `swift test`
  - Passed: 8 tests, 0 failures

## Commit
- `feat: store credentials and sign app store connect jwt`

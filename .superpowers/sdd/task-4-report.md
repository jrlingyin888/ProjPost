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

## Review Fixes (2026-07-02)

### What I fixed
- Reworked `KeychainCredentialVault.savePrivateKey` to use non-destructive add-or-update behavior:
  - attempt `SecItemAdd` first
  - on `errSecDuplicateItem`, call `SecItemUpdate` with the replacement key data and accessibility attribute
  - if update fails, throw the keychain status error without deleting the previous item
- Added a small injectable `KeychainClient` wrapper so `KeychainCredentialVault` logic can be tested deterministically without relying on the host Keychain.
- Strengthened JWT coverage to verify:
  - `iat` equals the supplied issued-at timestamp
  - `exp` equals `iat + 20 minutes`
  - the ES256 signature validates against the generated private key's corresponding public key
- Added credential vault tests covering save, update-on-duplicate, preserved-value-on-update-failure, read success, read not-found, invalid stored data, delete success, delete missing-item behavior, and delete error propagation.
- Kept local-only credential storage and on-demand JWT generation behavior unchanged; JWTs are still not persisted.

### Tests run and outputs
- Red phase:
  - `swift test --filter CredentialVaultTests`
  - Failed as expected before the vault refactor with:
    - `cannot find type 'KeychainClient' in scope`
    - `argument passed to call that takes no arguments`
- Focused vault tests:
  - `swift test --filter CredentialVaultTests`
  - Passed: 9 tests, 0 failures
- Focused JWT tests:
  - `swift test --filter AppStoreConnectJWTSignerTests`
  - Passed: 1 test, 0 failures
- Full suite:
  - `swift test`
  - Passed: 17 tests, 0 failures

### Files changed
- `Sources/ProjPostCore/Credentials/CredentialVault.swift`
- `Tests/ProjPostCoreTests/AppStoreConnectJWTSignerTests.swift`
- `Tests/ProjPostCoreTests/CredentialVaultTests.swift`
- `.superpowers/sdd/task-4-report.md`

### Commit created
- `fix: address task 4 credential vault review findings`

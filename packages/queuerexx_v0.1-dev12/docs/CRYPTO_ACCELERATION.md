# QueueRexx SHA-256 acceleration

## Rule

QueueRexx uses the existing ooRexx Crypto public API for SHA-256. It does not select a separate caller-facing API for "fast" hashing.

```rexx
digest = .SHA256~new(material)~digest
```

When hashing performance matters, the preferred runtime is the supplied Crypto Foreign Runtime provider. If the configured Foreign Runtime bridge paths are present, `QueueDigestProvider` lazily asks `CryptoForeignRuntimeInstaller` to register the OpenSSL implementation with Runtime Reference before calling `.SHA256`. The unchanged Crypto call is then dispatched as:

```text
operation: crypto.sha256.digest/1
provider:  foreign.openssl.crypto
backend:   Foreign Runtime -> OpenSSL/libcrypto
```

Pure ooRexx SHA-256 is the fallback when that provider is unavailable or intentionally not installed.

## QueueRexx objects

`QueueCryptoAcceleration~ensurePreferred` lazily installs the supplied provider from QueueRexx bridge configuration when it is available. `QueueCryptoAcceleration~install` is also available for explicit bootstrap. Neither replaces the Crypto API.

`QueueDigestProvider~digest` calls `.SHA256` directly.

`QueueDigestProvider~digestWithEvidence` also reads Runtime Reference's last execution evidence and reports whether the digest was actually accelerated. Configuration alone is not accepted as proof.

## Qualification

`tests/test_foreign_runtime_sha.rex` requires:

```text
known digest matches
Runtime Reference outcomeCode == COMPLETED
Runtime Reference providerId  == foreign.openssl.crypto
```

The main test runner also executes Migratable Job v0.2.4's own Foreign Runtime digest probe when exact dependencies are supplied, thereby proving Job-to-Node and migration provenance hashing use the same accelerated provider.

## Authority and portability

Crypto implementation selection is an execution/provider concern, not a QueueBash filesystem concern. No hashing-provider name is written into a QueueBash job record unless a future versioned audit schema explicitly requires it.

# Changelog

## v0.8.3

- Requalifies the byte-identical v0.8/v0.8.1/v0.8.2 Crypto implementation against user-supplied Foreign Runtime v0.22.2 while retaining Runtime Reference v0.4 unchanged.
- Confirms the accepted Foreign Runtime v0.17.2 concurrency/resource-pinning ancestry, v0.18 exact-binary buffer semantics, libffi/struct/pointer-array facilities, and concurrent native invocation used by Crypto remain compatible through v0.22.2.
- Confirms the v0.19-v0.22.2 Python/DLPack/tensor/device/Vulkan/proxy-indexing additions are orthogonal to Crypto's direct-libcrypto / five-function compatibility architecture and require no Crypto execution-semantic change.
- Fresh qualification passes both the pristine v0.22.2 prebuilt complete gate and a fresh source-built complete gate, all native Crypto tests, direct SHA, expensive-operation equivalence, both concurrency suites, hybrid isolation, live/dead TCP, Foreign -> TCP -> native failover, Runtime Reference v0.4, and Runtime Registry v0.14 full non-optional suite.
- No `src/`, `native/`, test, operation-id, TCP-wire, public API, or fallback semantic change from v0.8.2.

## v0.8.2

- Requalifies the byte-identical v0.8/v0.8.1 Crypto implementation against user-supplied Foreign Runtime v0.14.0 while retaining Runtime Reference v0.4 unchanged.
- Confirms v0.14.0 preserves every facility used by the direct-libcrypto architecture: runtime-loaded libffi, metadata-defined structs, typed pointer arrays, exact-binary `bytes`, resource pinning, concurrent provider execution, and the v0.13 callback/address-space inheritance.
- Confirms v0.14 scalar-owned handles, immediate `errno` capture, `i16`/`u16`, `ForeignStructArray`, and PTY/poll additions are orthogonal to Crypto and require no Crypto execution-semantic change.
- Fresh qualification passes the pristine v0.14.0 prebuilt complete gate, a fresh source-built complete gate, all native Crypto tests, direct SHA, expensive-operation equivalence, both concurrency suites, hybrid isolation, live/dead TCP, Foreign -> TCP -> native failover, Runtime Reference v0.4, and Runtime Registry v0.14 full non-optional suite.
- No `src/`, `native/`, test, operation-id, TCP-wire, public API, or fallback semantic change from v0.8.1.

## v0.8.1

- Requalifies the byte-identical v0.8 Crypto implementation against user-supplied Foreign Runtime v0.13.0 while retaining Runtime Reference v0.4 unchanged.
- Confirms v0.13.0 preserves every Foreign Runtime facility used by Crypto v0.8: runtime-loaded libffi, metadata-defined structs, typed pointer arrays, exact-binary `bytes`, resource pinning, and concurrent provider execution.
- Confirms v0.13.0 callback additions are not required by Crypto and do not alter the direct-libcrypto / five-function compatibility split.
- Fresh qualification passes native Crypto, direct SHA, expensive-operation equivalence, both concurrency suites, hybrid isolation, live/dead TCP, Foreign -> TCP -> native failover, Runtime Reference v0.4, and Runtime Registry v0.14 full non-optional suite.
- No `src/`, `native/`, test, operation-id, wire-protocol, or public Crypto semantic change from v0.8.

## v0.8

- Replaces the monolithic `crypto_rocket` ABI-convenience shim with direct Foreign Runtime v0.11/libffi bindings to system `libcrypto` for SHA-256/SHA-512, HMAC-SHA-512, ChaCha20, whole Ed25519, and RSA.
- Uses v0.11 metadata-defined `SizeTBox` / `I32Box` struct storage for C output-length pointers rather than wrapper packing.
- RSA keypair/key-generation/modular exponentiation are now direct BIGNUM calls; RSA text encrypt/decrypt use direct `BN_bin2bn` / `BN_bn2binpad` so no large private result is converted through slow Rexx divide-by-16 loops.
- Shrinks the package-owned C compatibility target to exactly five exports: Edwards25519 add/multiply, unclamped X25519 public/shared, and experimental Ed448 keypair.
- Adds a hybrid-isolation regression proving direct libcrypto remains usable without the compatibility library and compatibility operations remain usable when the direct definition is unavailable.
- Retains Runtime Reference v0.4, all semantic operation ids, process-wide concurrent PURE dispatch, TCP wire `runtime.reference/0.1`, and complete native ooRexx fallback.
- Qualifies both source-built and pristine prebuilt user-supplied Foreign Runtime v0.11.0 under ooRexx 5.3.0 r13196.

## v0.7

- Extends the thread-safe high-priority Foreign Runtime/OpenSSL provider from SHA-256/SHA-512 to the remaining expensive `PURE` Crypto operations: whole HMAC-SHA-512, bulk ChaCha20, Edwards25519 add/multiply, whole Ed25519 keypair/sign/verify, experimental Ed448 keypair, X25519 public/shared, and RSA key construction/generation/encrypt/decrypt/sign/verify.
- Adds a small OpenSSL/BIGNUM shim (`native/crypto_rocket.c`) so each semantic Runtime Reference operation remains one three-argument Foreign Runtime call; Crypto itself remains unaware of OpenSSL/EVP/BIGNUM.
- Preserves exact inherited semantics rather than substituting nearby standards: X25519 retains the package's current unclamped Montgomery-ladder behaviour; experimental Ed448 reproduces the existing SHA-512/clamp/Goldilocks approximation; RSA retains phi(n)-based `d` and the inherited textbook/text encoding rules; ChaCha20 retains counter 1.
- Adds whole-operation Runtime Reference boundaries for `crypto.hmac.sha512.digest/1`, `crypto.chacha20.crypt/1`, and `crypto.ed448.keypair/1`. Existing Ed25519/X25519/RSA/Edwards operation ids are now also served by the Foreign provider.
- Adds exact equivalence tests, an 8-activity shared-provider stress test, and Foreign -> TCP -> native failover tests for the expanded expensive-operation set.
- Fresh measurements on r13196 include ~0.27 ms Ed25519 sign/verify, ~1.23 ms X25519 shared secret, ~23 ms experimental Ed448 keypair, ~1.89 ms full Edwards multiply, ~0.35 ms HMAC-SHA-512 over 4 KiB, ~0.49 ms ChaCha20 over ~64 KiB, ~120 ms RSA-2048 key generation, and ~3-4 ms RSA-2048 private sign/decrypt.
- The native C shim builds cleanly with `-Wall -Wextra -Wpedantic`; it includes a reproducible `native/build_crypto_rocket.sh` and uses no POSIX-only `strndup`.
- Requalifies the complete v0.7 native/foreign/TCP/failover/concurrency stack against user-supplied Foreign Runtime v0.10.0 (SHA-256 `08d27d5ccc60eb4972afc69a5a20c80cb79bcf4e950892b0be9cd54f273df2e0`). v0.10.0 retains the required v0.8.1 thread-safe/binary-exact semantics while adding optional runtime-loaded libffi; the existing three-argument rocket shim remains ABI-compatible.

## v0.6.1

- Qualifies the SHA-256/SHA-512 Foreign Runtime acceleration path against user-supplied `oorexx_foreign_runtime_v0.8.1`, which makes ForeignLibrary invocation/resource lifetime thread-safe across real ooRexx activities and carries forward exact-binary `bytes` marshalling.
- Uses Runtime Reference v0.4, removing the v0.3 monitor serialization that previously prevented a shared broker/object provider from executing PURE calls concurrently.
- Marks `CryptoForeignRuntimeTarget~runtimeImplementationInvoke` `UNGUARDED`; its guarded lazy-library lookup remains a short initialization/read critical section and no OpenSSL call executes under the target monitor.
- Adds a 12-activity binary SHA stress test: 40 SHA-256 + SHA-512 pairs/activity over an 86,016-byte payload containing embedded NUL/high-bit bytes. All 960 digests pass through one shared `foreign.openssl.crypto` provider.
- Adds a four-activity 1 MiB throughput benchmark. Three repeated runs measured 3.32x-4.59x wall-clock speedup over the same sequential referenced workload, with aggregate throughput 1.55-1.87 GiB/s on the qualification container.
- Preserves Foreign -> TCP -> native failover, exact semantic operation IDs, public SHA APIs, and portable ooRexx fallback implementations.

## v0.6

- Adds `CryptoForeignRuntimeProvider.cls`, a high-priority resident Runtime Reference provider for `crypto.sha256.digest/1` and `crypto.sha512.digest/1` backed by Foreign Runtime v0.7.1 and OpenSSL `SHA256`/`SHA512` one-shot functions.
- Adds `.CryptoForeignRuntimeInstaller~install` to register both operations and install the process-wide switch without changing ordinary Crypto callers.
- Uses Runtime Reference v0.3 `RuntimeExactBytes` for byte-exact in-process hashing without pre-encoding the payload; TCP/JSON continues to emit the existing tagged `hex:` representation.
- Keeps Crypto core compatible with Runtime Reference v0.2 by using tagged hex when the installed switch does not expose `exactBytes`.
- Defers native SHA-256/SHA-512 engine initialization until native execution is actually required; successful references no longer pay portable word-engine setup cost.
- Adds exact-binary NUL/high-bit tests, Foreign/OpenSSL provider evidence checks, and explicit Foreign -> TCP -> native failover qualification.
- End-to-end 4 KiB measurements on r13196: SHA-256 4441.091 ms -> 0.2621 ms (**16942.75x**); SHA-512 4049.895 ms -> 0.2804 ms (**14442.59x**).
- Accelerated-only 1 MiB throughput: ~507.50 MiB/s SHA-256 and ~465.28 MiB/s SHA-512.

## v0.5

- Adds `crypto.sha512.digest/1` as a whole-operation `PURE` Runtime Reference boundary while preserving `.SHA512~new(data)~digest`, streaming `update()`, `CryptoHash~hashString("SHA512", ...)`, HMAC-SHA-512, Ed25519/Ed448, and `CryptoStream~sha512/hash("SHA512")`.
- Uses the same tagged exact-byte hexadecimal transport as SHA-256 and validates provider output as exactly 128 lowercase hexadecimal characters.
- Invalid completed provider results are recorded as `RESULT_VALIDATION_FAILED`; unavailable/unsupported providers retain native SHA-512 fallback where Runtime Reference marks fallback safe.
- Adds live TCP provider equivalence, streaming-facade, invalid-result fallback, and service-absent fallback tests.
- Runtime Reference remains v0.2 and the TCP wire remains `runtime.reference/0.1`.

## v0.4

- Adds a native streaming SHA-256 implementation with standard known-answer and multi-block tests.
- Adds `crypto.sha256.digest/1` as a whole-operation `PURE` Runtime Reference boundary while keeping `.SHA256~new(data)~digest` unchanged.
- Adds `SHA256` to `CryptoHash~hashString`, plus `CryptoStream~sha256` and `CryptoStream~hash("SHA256")`.
- Uses tagged hexadecimal request bytes so arbitrary ooRexx data crosses JSON exactly and all-decimal hex is never retyped as a JSON number.
- Adds Python `hashlib.sha256` provider support, explicit `COMPLETED` evidence checks, invalid-result rejection/native fallback, and service-unavailable native fallback.
- Adds end-to-end SHA-256 benchmarks: 16.26x at 16 B, 101.06x at 1 KiB, 151.62x at 4 KiB, and 163.81x at 16 KiB in the qualification environment.
- Leaves Runtime Reference at v0.2; no generic broker/wire change is required.

## v0.3

- Continues from the exact Codex-tested Crypto source supplied by the user, which adds whole-operation Ed25519 `keypair/sign/verify` Runtime Reference hooks on top of packaged v0.2.
- Adds whole-operation Runtime Reference switching for RSA `keypair`, `generateKeypair`, `encrypt`, `decrypt`, `sign`, and `verify` while preserving the public API and complete native implementations.
- Adds local validation of provider RSA key material and numeric result ranges; text RSA operations use hex payloads to preserve ooRexx byte strings across JSON.
- Adds an optimized resident Python reference service. RSA-2048 key generation uses OpenSSL-backed prime generation but derives `d` exactly as the ooRexx implementation does: inverse of `e` modulo `phi(n)`.
- Adds live RSA TCP equivalence tests and service-unavailable native fallback tests with explicit `COMPLETED` provider evidence assertions.
- Adds whole-operation Ed25519 live-provider evidence assertions so a benchmark cannot mistake native inner-operation fallback for successful public-operation dispatch.
- Adds RSA-2048 same-key benchmark: ~489x private sign, ~486x private decrypt, ~114x verify, and ~90x encrypt speedups in the qualification environment.
- Requalifies Runtime Reference v0.2 and Runtime Registry v0.14 non-optional suites.

## v0.2

- Adds optional execution-location switching for Edwards25519 add/multiply and X25519 public/shared operations while retaining native fallback.

## v0.1

- Establishes standalone shared Crypto, shared MAC primitives, and ChaCha20 conformance repair.

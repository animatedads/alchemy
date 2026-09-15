# ooRexx Crypto v0.8.3

`oorexx_crypto_v0.8.3` is the shared cryptographic primitive package for the current ooRexx library line. It preserves complete native ooRexx implementations while allowing selected `PURE` operations to be late-bound through Runtime Reference without changing the public call surface.



## v0.8.3 — Foreign Runtime v0.22.2 qualification

v0.8.3 is a qualification/provenance increment over v0.8.2. The Crypto implementation, native compatibility library, tests, operation ids, public API and fallback semantics are unchanged. It is freshly qualified against the user-supplied Foreign Runtime v0.22.2 and sealed Runtime Reference v0.4.

Foreign Runtime v0.22.2 preserves the exact-binary, libffi, struct/pointer-array, resource-pinning and concurrent native invocation facilities used by Crypto. The intervening Foreign Runtime work adds bidirectional Python zero-copy buffers, provider-neutral tensor/DLPack descriptors, device-aware tensor execution metadata, optional Vulkan, and Python proxy/indexing fixes. Those facilities are additive and orthogonal to Crypto's direct-libcrypto / five-function compatibility split.

The preferred execution chain remains:

```text
ordinary Crypto method
    -> Runtime Reference v0.4
       -> direct Foreign Runtime v0.22.2/libcrypto when semantics match
       -> tiny compatibility Foreign Runtime target when semantics differ
       -> lower-priority provider (for example TCP/Python)
       -> native ooRexx fallback
```

## v0.8.2 — Foreign Runtime v0.14 qualification

v0.8.2 is a qualification/provenance increment over v0.8.1. The Crypto implementation, native compatibility library, tests, operation ids, public API and fallback semantics are unchanged. It is freshly qualified against the user-supplied Foreign Runtime v0.14.0 and sealed Runtime Reference v0.4.

Foreign Runtime v0.14.0 preserves the v0.13 callback/address-space line plus all libffi/struct/pointer-array/exact-binary/resource-pinning/concurrency facilities used by Crypto. Its new scalar-owned `ForeignHandle` resources, call-local `errno`, `i16`/`u16`, `ForeignStructArray`, and PTY/poll support are not required by Crypto and therefore do not alter the direct-libcrypto / five-function compatibility split.

The preferred execution chain remains:

```text
ordinary Crypto method
    -> Runtime Reference v0.4
       -> direct Foreign Runtime v0.14/libcrypto when semantics match
       -> tiny compatibility Foreign Runtime target when semantics differ
       -> lower-priority provider (for example TCP/Python)
       -> native ooRexx fallback
```


## v0.8.1 — Foreign Runtime v0.13 qualification

v0.8.1 is a qualification/provenance increment over v0.8. The Crypto implementation itself is unchanged. It is freshly qualified against the user-supplied Foreign Runtime v0.13.0 and sealed Runtime Reference v0.4. Foreign Runtime v0.13 retains the v0.11 libffi/struct/pointer-array facilities used by the direct libcrypto bindings, the v0.8 concurrency/resource-pinning model, and exact-binary `bytes`; its new call-scoped callback facility is intentionally unused by Crypto.

The architectural split therefore remains unchanged: standard OpenSSL-equivalent operations bind directly to system libcrypto through Foreign Runtime metadata/libffi, while `libcrypto_compat.so` remains restricted to the five operations whose inherited ooRexx semantics intentionally differ from OpenSSL. Public Crypto APIs, Runtime Reference operation ids, TCP wire `runtime.reference/0.1`, and native ooRexx fallback are unchanged.

## v0.8 — direct libcrypto where it actually means the same thing

v0.8 is the architectural-tidiness release for the expensive Foreign Runtime path. It is qualified with Runtime Reference v0.4 and the user-supplied Foreign Runtime v0.11.0. Standard operations no longer pass through the package-owned three-argument `crypto_rocket` wrapper merely for ABI convenience. `CryptoForeignRuntimeProvider.cls` now loads `native/openssl_direct.bridge.json` and invokes libcrypto directly through v0.11/libffi.

Direct metadata/libffi operations include SHA-256, SHA-512, HMAC-SHA-512 (`EVP_Q_mac`), ChaCha20 (EVP), whole Ed25519 keypair/sign/verify, and all existing RSA key construction/generation/encrypt/decrypt/sign/verify operations using OpenSSL BIGNUM. Foreign Runtime v0.11 metadata-defined scalar structs provide safe native storage for `size_t *` and `int *` parameters, so these calls do not need C wrappers just to carry output lengths.

A deliberately smaller compatibility library remains because three existing Crypto semantics are *not* standard OpenSSL operations: raw Edwards25519 add/multiply, the package's intentionally unclamped X25519 ladder, and the experimental SHA-512/Goldilocks Ed448 keypair. `native/libcrypto_compat.so` exports only those five entry points. A missing compatibility library does not disable direct SHA/HMAC/ChaCha/Ed25519/RSA acceleration, and a broken direct definition does not disable the compatibility operations; both directions are explicitly tested.

The semantic and fallback chain is unchanged:

```text
ordinary Crypto method
    -> Runtime Reference v0.4
       -> direct Foreign Runtime v0.11/libcrypto when semantics match
       -> tiny compatibility Foreign Runtime target when semantics differ
       -> lower-priority provider (for example TCP/Python)
       -> native ooRexx fallback
```

Representative v0.11 direct/hybrid timings on the qualification environment are ~0.56-0.65 ms Ed25519 sign/verify, ~0.43 ms HMAC-SHA-512 over 4 KiB, ~0.74 ms ChaCha20 over ~64 KiB, ~3.7 ms RSA-2048 private sign/decrypt, ~55-95 ms RSA-2048 key generation, ~0.9 ms unclamped X25519 shared secret, ~1.8-2.8 ms Edwards multiply, and ~25 ms experimental Ed448 keypair. The direct path is intentionally a little more FFI-chatty than the old monolithic wrapper for some operations, but remains orders of magnitude faster than portable ooRexx while removing unnecessary C glue.

## v0.7 — expensive crypto on the same rocket skates

v0.7 keeps the ordinary ooRexx API and the thread-safe Runtime Reference v0.4 / Foreign Runtime v0.10.0 stack, but moves the other expensive PURE operations onto a high-priority OpenSSL-backed resident provider as well. Crypto does not call OpenSSL directly: `.CryptoForeignRuntimeInstaller~install` registers `foreign.openssl.crypto`, whose target uses Foreign Runtime metadata plus the bundled `libcrypto_rocket.so` shim. Lower-priority Runtime Reference providers and the complete native ooRexx implementations remain available as fallback.

Accelerated semantic operations now include SHA-256/SHA-512, HMAC-SHA-512, ChaCha20, Edwards25519 add/multiply, whole Ed25519 keypair/sign/verify, experimental Ed448 keypair, X25519 public/shared, and all existing RSA Runtime Reference operations. Each completed foreign result is still locally validated by the owning Crypto method before acceptance.

The shim deliberately preserves this package's existing semantics. In particular, current X25519 scalar handling is left unclamped; experimental Ed448 remains the package's SHA-512/Goldilocks approximation rather than RFC Ed448; RSA retains `d = e^-1 mod phi(n)` and the inherited textbook/text encoding; and ChaCha20 starts at counter 1. This release is an execution acceleration, not a cryptographic API/semantic rewrite.

Representative end-to-end foreign timings on the qualification environment:

| operation | native ooRexx | Foreign Runtime/OpenSSL | approximate speedup |
| --- | ---: | ---: | ---: |
| Ed25519 keypair | 2136.189 ms | 0.508 ms | **4205x** |
| Ed25519 sign | 4538.344 ms | 0.274 ms | **16563x** |
| Ed25519 verify | 3851.883 ms | 0.267 ms | **14427x** |
| X25519 shared secret | 126.186 ms | 1.226 ms | **103x** |
| experimental Ed448 keypair | 3980.299 ms | 23.143 ms | **172x** |
| Edwards25519 multiply | 1555.158 ms | 1.887 ms | **824x** |
| HMAC-SHA-512, 4 KiB | 3550.883 ms | 0.353 ms | **10059x** |
| ChaCha20, ~4 KiB | 2142.120 ms | 0.224 ms | **9563x** |

RSA-2048 accelerated-only timings are ~120.207 ms key generation, ~3.246 ms private sign and ~3.865 ms private decrypt. The inherited native RSA-2048 private path is intentionally slow; historical same-implementation baselines were ~13.3 s sign and ~13.0 s decrypt.

The expanded provider is also concurrency-qualified through one shared Runtime Reference broker/provider across eight ooRexx activities, and failover is proven Foreign Runtime -> TCP provider -> native ooRexx.

Foreign Runtime v0.10.0 supersedes the earlier v0.8.1 qualification substrate for this sealed candidate. v0.10.0 retains the v0.8.1 thread-safe resource pinning and binary-exact `bytes` semantics and adds optional runtime-loaded libffi on qualified x86-64 POSIX. The current Crypto rocket shim deliberately remains valid through the legacy three-argument ABI shape, so the substrate upgrade requires no crypto semantic change; it simply removes the old fixed-arity ceiling for future providers when libffi is available.

## v0.6.1 — thread-safe SHA-256/SHA-512 rocket skates

v0.6.1 carries the high-priority in-process Runtime Reference provider forward onto thread-safe `oorexx_foreign_runtime_v0.8.1` and Runtime Reference v0.4 and OpenSSL `libcrypto`. It calls the three-argument one-shot `SHA256(data,len,out)` and `SHA512(data,len,out)` symbols directly, eliminating TCP/JSON from the preferred hash path while preserving the same public `.SHA256` / `.SHA512` calls and semantic Runtime Reference operation ids.

The provider is installed with:

```rexx
installed = .CryptoForeignRuntimeInstaller~install
```

The resulting preference chain is deployment-controlled and was qualified as:

```text
Foreign Runtime -> OpenSSL libcrypto
        | unavailable
        v
next Runtime Reference provider (for example TCP/Python)
        | unavailable
        v
portable native ooRexx implementation
```

Runtime Reference v0.3 introduced `RuntimeExactBytes`; v0.4 preserves it and adds concurrent PURE dispatch: resident providers receive the original ooRexx bytes, including embedded NULs, without hexadecimal conversion; the TCP provider serializes the same value back to the existing `hex:<...>` wire representation, so the Python `runtime.reference/0.1` service remains compatible. Crypto v0.6 also makes SHA native-engine setup lazy, so a successful referenced digest does not pay to construct the portable SHA state first. Crypto's core reference path remains compatible with Runtime Reference v0.2 by falling back to the prior tagged-hex request when `exactBytes` is unavailable.

### Concurrency

The accelerated path is now qualified as a shared process-wide provider across real ooRexx activities. Runtime Reference v0.4 does not hold its switch/broker/provider monitors across provider execution, `CryptoForeignRuntimeTarget~runtimeImplementationInvoke` is `UNGUARDED`, and Foreign Runtime v0.8.1 pins library/buffer resources per active call while allowing native calls to overlap.

A 12-activity stress performs 40 SHA-256 and 40 SHA-512 calls per activity over an 86,016-byte binary payload containing NUL and `ff` bytes through one shared provider. All 960 digests match fixed known results. A separate four-activity 1 MiB benchmark repeated three times produced 3.32x, 3.54x and 4.59x wall-clock speedups over the same sequential referenced workload, with 1.55-1.87 GiB/s aggregate throughput on a 5-vCPU qualification container.

`RuntimeImplementationBroker~lastEvidence` is process-global observational state; under concurrency it denotes whichever call published most recently. Per-call correctness uses the evidence carried by each `RuntimeImplementationAttempt`.

### Foreign Runtime/OpenSSL performance proof

End-to-end ooRexx call timings under ooRexx 5.3.0 r13196, including Crypto dispatch, Runtime Reference broker/evidence, Foreign Runtime metadata dispatch, OpenSSL, output-buffer conversion and local result validation:

| algorithm | payload | native ooRexx | Foreign Runtime/OpenSSL | speedup |
|---|---:|---:|---:|---:|
| SHA-256 | 16 B | 82.086 ms | 0.2396 ms | **342.56x** |
| SHA-256 | 1 KiB | 1062.765 ms | 0.2597 ms | **4091.67x** |
| SHA-256 | 4 KiB | 4441.091 ms | 0.2621 ms | **16942.75x** |
| SHA-512 | 16 B | 129.418 ms | 0.1937 ms | **668.01x** |
| SHA-512 | 1 KiB | 896.337 ms | 0.1873 ms | **4786.67x** |
| SHA-512 | 4 KiB | 4049.895 ms | 0.2804 ms | **14442.59x** |

Accelerated-only 1 MiB measurements were ~1.9705 ms / **507.50 MiB/s** for SHA-256 and ~2.1493 ms / **465.28 MiB/s** for SHA-512. Every accelerated benchmark asserts Runtime Reference evidence `outcome=COMPLETED` and `provider=foreign.openssl.crypto`.

## SHA-256

v0.5 adds a native streaming `.SHA256` implementation and makes the complete digest a Runtime Reference operation. The ordinary API remains:

```rexx
digest = .SHA256~new(data)~digest
```

With no Runtime Reference switch installed this is pure ooRexx. With a switch installed at construction time, input is retained until `digest()` and the whole hash can be executed by a preferred provider. Provider failure, unsupported execution, malformed result, or failed local digest validation falls back to the native implementation. Streaming callers (`new` + one or more `update` calls + `digest`) retain the same public semantics.

`CryptoHash~hashString(..., "SHA256")` and `CryptoStream~sha256` / `CryptoStream~hash("SHA256")` are also supported.

The development TCP provider uses Python `hashlib.sha256`, which is backed by the platform optimized crypto implementation. The wire request carries exact ooRexx bytes as tagged hex (`hex:<lowercase-hex>`) to avoid JSON numeric/string ambiguity and text-encoding changes.

### SHA-256 performance proof

Single-operation end-to-end timings on the supplied ooRexx 5.3.0 r13196 debug runtime, including broker dispatch, JSON, TCP, provider execution, result parsing, evidence and local validation:

| payload | native ooRexx | Runtime Reference TCP/Python | speedup |
|---:|---:|---:|---:|
| 16 B | 64.854 ms | 3.988 ms | 16.26x |
| 1 KiB | 990.924 ms | 9.805 ms | 101.06x |
| 4 KiB | 3632.712 ms | 23.959 ms | 151.62x |
| 16 KiB | 15082.886 ms | 92.078 ms | 163.81x |

The fixed dispatch/transport cost dominates very small inputs; larger inputs rapidly expose the benefit of the optimized provider. High-volume consumers that already batch many hashes (for example Semantic Source Control) should preserve batching rather than replacing one batch with one TCP call per item; a future batch reference operation can amortize transport while retaining individual digest identities.

## SHA-512

v0.5 adds `crypto.sha512.digest/1` as the whole-operation `PURE` Runtime Reference equivalent of the v0.4 SHA-256 boundary. `.SHA512~new(data)~digest`, streaming `update()`, HMAC-SHA-512 and existing Ed25519 callers retain their public API. When a switch is installed before construction, exact input bytes are retained until `digest()` and may be delegated to the selected provider. Provider output must be exactly 128 lowercase hexadecimal characters. Unsupported/unavailable providers and rejected values fall back to the preserved native SHA-512 implementation when Runtime Reference evidence permits fallback.

## Runtime implementation references

Runtime Reference remains optional at load time. `CryptoLibraryBuild~referenceSwitch` defaults to `.nil`; with no injected switch every operation executes natively.

With `runtime_reference_v0.4` loaded, a deployment may install `.RuntimeImplementationSwitch` and bind semantic operation IDs documented in `REFERENCE_OPERATIONS.md`. v0.5 includes:

- SHA-256 whole digest;
- Edwards25519 add/multiply;
- whole Ed25519 keypair/sign/verify;
- X25519 public-key/shared-secret;
- RSA keypair from supplied primes;
- RSA-2048 generated keypair;
- textbook RSA text encrypt/decrypt;
- textbook RSA raw sign/verify.

The same `.SHA256~new(data)~digest`, `.RSA~sign(...)`, `.RSA~decrypt(...)`, `.Ed25519~sign(...)`, etc. calls therefore remain visible to callers while execution may occur in native ooRexx, a resident TCP service, a BSF4ooRexx/Java provider, or another Runtime Reference provider.

Provider results are treated as untrusted values and locally validated before they are returned. A provider failure, unsupported operation, malformed response, or rejected result falls back to the preserved native implementation whenever the `PURE` contract permits it.

The development Python service is an equivalence/performance provider, not a production private-key transport. Production RSA private-key providers should prefer provider-owned key handles (for example Java JCA/HSM-backed references) instead of transporting private exponents over plaintext TCP.

## RSA performance proof

On the supplied ooRexx 5.3.0 r13196 debug runtime, using one provider-generated RSA-2048 key and identical operands:

| operation | native ooRexx | Runtime Reference TCP/Python | speedup |
|---|---:|---:|---:|
| raw private sign | 13276.099 ms | 27.163 ms | 488.76x |
| raw public verify | 410.436 ms | 3.608 ms | 113.76x |
| text public encrypt | 292.780 ms | 3.239 ms | 90.39x |
| text private decrypt | 12966.781 ms | 26.707 ms | 485.52x |

Provider/OpenSSL-backed 2048-bit prime generation plus ooRexx-compatible `d = e^-1 mod phi(n)` derivation took 68.839 ms in that qualification run. Native 2048-bit key generation is deliberately not a pass/fail benchmark because it is extremely slow.

## Compatibility and security scope

The RSA surface remains the inherited textbook/reference RSA API. v0.5 does **not** turn it into a modern padded RSA signature/encryption scheme. Existing callers and semantics are preserved.

The package also retains SHA-512, Ed25519, HMAC-SHA-512, SipHash-2-4-128, ChaCha20, X25519, MD5 compatibility code, experimental Ed448 helpers, RSAStream, and CryptoStream.

## Tests

```sh
REXX=/path/to/rexx \
RUNTIME_REFERENCE_SRC=/path/to/runtime_reference_v0.4/src \
./run_tests.sh
```

The suite covers SHA-256 known-answer and streaming tests, original cryptographic compatibility tests, live TCP reference equivalence, explicit provider evidence, invalid-result fallback, and service-disappearance native fallback for SHA-256, elliptic-curve operations and RSA. Runtime Registry v0.14's full non-optional suite is requalified against Crypto v0.8.

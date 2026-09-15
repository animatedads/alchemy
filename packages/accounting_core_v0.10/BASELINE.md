# Accounting Core v0.10 baseline

Parent accepted candidate: `accounting_core_v0.9.zip` (SHA-256 `0376a4a49d57b8ceff11fc38183145fc708f0d1843f74524e16fa1a5aa1db1f0`).

v0.10 is additive above the v0.8 sealed snapshot and v0.9 attestation/submission contracts. It adds immutable filing versions and append-only filing lifecycle evidence; it does not change posting, transaction, persistence, tax, settlement, scope, reporting-boundary, snapshot, attestation or submission API generations.

Integration baseline: user-supplied `oorexxapis(20260901-112242).zip` (SHA-256 `9f95981d13a9cf6b51aaa032f6c7c401615b3f53609b4a240268bccd13cd5d63`). That roll-up contains Accounting Core v0.8, which is older than this line, and FederationBank Merchant Accounting Adapter v0.5, which explicitly consumes the retained v0.7 accounting/settlement contracts. No consumer-facing compatibility regression was required.

The optional reporting Crypto adapter is rebased to the roll-up's `oorexx_crypto_v0.8.3.zip` (SHA-256 `5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49`), with vendored `crypto.cls` SHA-256 `924d4baa9e5d536f3b1433ccaf73edb1aee3e35c31c860f8ee35d350f1b396b6`.

All Accounting Core source packages continue to require `::OPTIONS DIGITS 50`.

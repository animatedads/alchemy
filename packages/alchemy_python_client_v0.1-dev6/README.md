# Alchemy for Python 0.1-dev6 — source delta (27 October 2026)

**Component:** alchemy-for-python. Independent Python SDK only; do not modify the independent ooRexx Python Macrospace bridge or JosepMariaBlasco/oorexxpython upstream adapter.

This GitHub checkpoint contains the **additive dev5→dev6 sources/patch and regression tests**, **not** the complete 62-member standalone distribution. Complete dev6 ZIP SHA-256: `aebfeed2249aa2fc08b57b9b98458a5225d80a67814eb190c369301791b05daa`. The full ZIP is separately delivered in the user Library/conversation. Do not claim it has been imported byte-for-byte into GitHub.

Changes: live retained RexxObject.send() selector wrapper, exact ConnectResult getters, explicit 0/1 decoder rather than Python truthiness, and named destination for REQUEST and NOTIFY. Native selector remains authoritative for provider selection, strict route policy and no retry after ambiguous side effects. Native options must be encoded into a real ooRexx Directory/Table by the host; Python dictionaries are only test doubles.

Python qualification: 87 tests passed, 79 inherited plus eight new projection double tests. Python 3.13. **Native integration not run**: no `rexx` or `rexxc` executable on this build host. Explicitly not qualified: cross-runtime Macrospsace invocation, real Queue Fabric/JMS, RTO2 failover, or RPC/gRPC against the installed ooRexx server.

Reviewed source: ConnectSelector `0.1-dev7` (ZIP SHA-256 `146a9f89368b29c790629500dd932a881da283119b5abdeeada7bb74e5e27313`), RPC portfolio `0.1-dev1`, and separately the distinct upstream `alchemy_oorexxpython_upstream_adapter_v0.2`. The accepted independent Macrospace remains 0.31.7 unless native qualification supersedes it.

## Missing integration gates

1. Provision exact ooRexx / independent Macrospace runtimes; compile, retain and call live `ConnectSelector` and native six-field `ConnectIntent`, validate real Directory/Table options and eight ConnectResult getters.
2. Prove named-route denials, native boolean decoding, exception preservation and uncertain ACK, with no retry or provider fallback.
3. Run DirectCall, JSON-RPC hex8/TCP, explicit QueueFabric ENQUEUE, and gRPC unary/stream against **real** registered ooRexx services and TLS authority.
4. Prove JMS broker receipt, redelivery/dead-letter/transaction semantics and real RTO2 fencing separately; never conflate ENQUEUE receipt, job acceptance and completed work.
5. Import the complete version-pinned Python source tree to GitHub with manifest verification and CI on ooRexx-equipped hosts.

## Installation/usage

Apply the patch to the authoritative `alchemy_python_v0.1-dev5` tree, add `src/alchemy_python/native_projection.py` and the eight contract tests, then use the complete v0.1-dev6 delivery for independent installation. This source delta itself is not a standalone pip package.

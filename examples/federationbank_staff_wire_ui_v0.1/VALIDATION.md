# FederationBank Staff Wire UI v0.1 validation

Qualification target: `oorexxapis(20260828-191958).zip` under the supplied
ooRexx 5.3.0 r13196 Internal Test Version runtime.

Fresh packaged acceptance: **9/9 green**.

1. Wire UI release compilation and exact seven-definition catalogue.
2. Server-owned work scope plus Wire UI Server v0.17 result-revision authority;
   forged/out-of-scope selection and stale result context fail closed.
3. Exact Staff Method Permission required before a customer transfer is admitted;
   browser-supplied staff/session/branch/operation values cannot replace the
   server-owned values.
4. Unbound semantic action and invalid transfer input fail before permission;
   duplicate Wire UI message ID is replayed without a second permission call or
   second Staff Channel work item.
5. Actual ooRexx r13196 `AlchemySecurityManager` method-permission boundary is
   exercised; its admission explicitly implies neither Staff Authority, Access
   Control nor authentication.
6. Runtime metadata and Queue Fabric/Wire UI gateway service seam load/compile.
7. Browser bootstrap parser/projection shell syntax and bootstrap authority tests.
8. Non-authoritative preview boundary: no live transport/state logic.
9. Canonical starter: preview serves successfully; live mode fails closed unless
   authoritative bootstrap configuration is supplied.

The transcript is retained at `evidence/VALIDATION_TRANSCRIPT.txt`.

## Deliberate early-UI limitation

This v0.1 qualification does **not** claim a complete Staff Banking production
browser deployment. The live browser shell and ooRexx Web Gateway seam are
present, but a dedicated Staff Banking browser -> WebSocket -> Queue Fabric ->
Wire UI Server acceptance fixture is deferred to the next UI increment. The
backend authority boundary itself is exercised with the real r13196 Security
Manager in this package.

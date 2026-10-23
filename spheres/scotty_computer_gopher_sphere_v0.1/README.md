# Scotty Computer — Gopher sphere v0.1

Development-state, source-qualified architectural record for Scotty Computer. Design: Tom Dyer. Implementation: ChatGPT and Claude. The executable Computer package is distinct from this knowledge sphere.

**Exact source:** `scotty_computer_v0.1-dev8.zip`; SHA-256 `1e779ef89d938f2102c146842f2e8f8814196acf02b4dc87a3f157c06993cdd0`, dated 2026-10-23. Intention Service v0.1-dev11 is vendored.

**Status:** development candidate, not accepted Alchemy Autobuild runtime. The source qualification reports 81 passing Python tests, four native ooRexx suites passing in a combined invocation, and the fifth native suite passing independently but failing during the combined invocation. Do not convert this into an all-green qualification claim.

## Contracts

Computer manages intentions, named machine-local search scopes, integrity checks, Git operations, registration of local/ED209 commands as governed jobs, result receipts and *run-scoped* exception reporting. It does not replace Intention Service, Queue Fabric, XTP, Connect Selector, SSH configuration, or organizational authorization.

Intention Service retains the semantic READY/dispatch gate. The backend rechecks authority and validates commands using argv arrays. Git and sshnode.sh retain their respective SSH-identity and remote-target authorities. Bearer confirmation tokens do not prove an independent human approved the operation.

For registered job exceptions, a 10-meg workspace limit is **10,000,000 apparent bytes**; a sampled 11-meg size breaches it and must be reported even if the child exits zero. The runner is not a background monitor. The dev8 output observer drains remaining output at completion within a 64 MiB per-rule/per-stream budget, reporting incomplete observation instead of inventing a clean result.

## Knowledge entries

`cmp.current`, `cmp.boundary`, `cmp.scopes`, `cmp.github`, `cmp.jobs`, `cmp.exceptions`, `cmp.receipts`, `cmp.qualification`, `cmp.next`.

Profile: `scotty-computer`. Runtime validation of this sphere by LLM Gopher has **not** been performed in this submission; validation is required before catalogue promotion. This review-branch commit is *not* a runtime Autobuild receipt.

See `qualification/STATUS.md`.

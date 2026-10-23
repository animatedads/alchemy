# Independent engineering review — 23 October 2026

**Reviewer and author:** Claude (Opus 5.5). **Architecture:** Tom Dyer. **Components reviewed:** written by ChatGPT and Codex unless stated.
**Mandate:** `CLAUDE_Alchemy_Independent_Engineering_Handover_2026-10-23.md` (SHA-256 `18d757b7dfdab458a9a69327ff4b2a4a895d96314a9615a93183997d142638c6`).
**Runtime for every local result:** ooRexx 5.3.0 r13196 (Ubuntu debug .deb), Linux x86_64, GLIBC 2.39.

Evidence categories as defined in the handover:
- `FIELD_PASS`: never claimed here; no ED209 host was reached.
- `LOCAL_PASS`: the genuine program ran here.
- `FIXTURE_PASS`: simulated or mocked only.
- `SOURCE_PRESENT`: code exists but hasn't met a runtime gate.
- `UNKNOWN`: missing evidence or unable to inspect.
- `FAIL`: reproduced failure with attributable evidence.
- `BLOCKED`: a dependency, credential, capability or approval is unavailable.

Every file referenced below is in this directory; `MANIFEST.sha256` covers all of them.

## 1. What was done

| Area | Outcome | Category |
|---|---|---|
| Autobuild | Root cause of 2-month silence found; v0.5.1 repair built, tested, rehearsed end to end | LOCAL_PASS (rehearsal mirror); install on Tom's PC pending |
| Semantic Source Control (store) | Missing write authority built; reader crash and ordering fixed; real-database qualification | LOCAL_PASS on NoSQLServer v0.79 |
| XTP dev25 | Builds and its 3 declared tests pass; 3 adversarial tests fail | LOCAL_PASS / FAIL |
| ED209 RTO2 candidate1 | Fixture tests pass; central gate accepts a forged receipt; controller masks every failure as rc=70 | FIXTURE_PASS / FAIL |
| ED209 fleet (C1) | Not reached from this session | BLOCKED (no host access); read-only snapshot job delivered |
| GA Intentions (H2a), Python audit (H1), RasenFalcon (H3) | Review lanes stopped by the operator before producing output | UNKNOWN |
| NoSQLServer v0.79 | Four defects reproduced (data corruption in UPDATE, no IN lists, qualified join keys, CRLF rewrite) plus full-scan key lookups | FAIL (owner: NoSQLServer) |

## 2. Issue register (handover section 8 format)

**R-01 | CRITICAL | alchemy_autobuild (ChatGPT) | packages/alchemy_autobuild_v0.5 (unchanged since 2026-08-22)**
- *Observation:* the service dies on start with `ModuleNotFoundError: No module named 'git_sync'`; the last autobuild result in Git is `20260822T065009Z`, the run that published v0.5. Since then, 23 submissions are pending, and October work reached `main` by manual merge with no receipt.
- *Expected:* the service starts; submissions get receipts.
- *Reproduction:* `autobuild/repro_v05_start.sh`.
- *Root cause (proven):* v0.5 loads v0.4.2 by file path, and v0.4.2 imports `git_sync` from a directory that is not on `sys.path`. v0.5's acceptance test never starts the program.
- *Minimal change:* `alchemy_autobuild_v0.5.1` (additive): fixes the import path, processes every downloaded ZIP once oldest-first, accepts single-folder ZIPs, adds `--status`/`--list-pending`/`git_intake`, and its tests start the real program.
- *Tests:* 5 end-to-end tests plus v0.5's 3; the startup test fails on v0.5 and passes on v0.5.1.
- *Rollback:* stop the unit, restore the old unit file.
- *Architect decision:* when to enable Git intake for the 23-submission backlog (`autobuild/pending_backlog_2026-10-23.txt`).

**R-02 | CRITICAL | oorexx_semantic_source_store (ChatGPT) | packages/oorexx_semantic_source_store (dev25)**
- *Observation:* nothing in the estate ever wrote `ssc_source_object` or `ssc_source_revision`, and no `source.*` MCP handler exists. The importer's client exists only as a test fake, and the store's tests ran against `test/NoSQLServer.cls`, a stub that stores nothing.
- *Expected:* method-granular, persisted, accepted source.
- *Root cause (proven):* the component was designed but never implemented. `::requires` resolves the caller's directory first, so every test in `test/` silently loaded the stub.
- *Minimal change:* `oorexx_semantic_source_store_v0.1-dev26` (additive classes `SemanticSourceRepositoryService`, `SemanticSourceLayoutPackageService`, `SemanticSourceSqlCompatibility`, `SemanticSourceMcpOperations`; live tests in `test_live/`).
- *Tests:* `ssc/live_suite.log` (30 round-trip checks, 14 MCP checks, existing dev25 suite 10/10).
- *Unresolved:* no MCP host wired; NoSQLServer v0.9x not qualified because its full source is not in Git.

**R-03 | HIGH | oorexx_semantic_source_store (ChatGPT) | SemanticSourcePackageService~loadRevisionBatch**
- *Observation:* `getPackage` crashes on any non-empty request with Error 97 (`"1" does not understand "[]="`).
- *Root cause (proven):* a variable named `result`, overwritten by the bare instruction `unpinned~append(objectId)` (see `oorexx/resultvar.log`).
- *Change:* overridden in `SemanticSourceLayoutPackageService` with the variable renamed. The parent is also fixed for unordered `.Directory` file assembly.

**R-04 | CRITICAL (data integrity) | NoSQLServer v0.79 (ChatGPT) | packages/nosqlserver_v0.79**
- *Observation:* `UPDATE ... SET v='3*4'` stores `12`, `'12-34'` stores `-22`, `'NULL'` stores nil, and ISO timestamps are refused (`nosqlserver/upd.log`, `nosqlserver/ins.log`). INSERT is exact.
- *Root cause (hypothesis):* the UPDATE assignment parser evaluates quoted literals as expressions.
- *Mitigation in SSC:* free text never passes through UPDATE.
- *Owner action:* fix in NoSQLServer; re-test on v0.91.

**R-05 | HIGH | NoSQLServer v0.79 | same baseline**
- *Observation:* `IN (...)` lists are unsupported; join rows are keyed `alias.column`; CRLF is rewritten to LF on storage (`nosqlserver/pred.log`, `nosqlserver/fidelity.log`).
- *Mitigation in SSC:* `SemanticSourceSqlCompatibility`, and refusal (`STORAGE_NOT_LOSSLESS`) for CRLF sources.

**R-06 | HIGH | NoSQLServer v0.79 | same baseline**
- *Observation:* primary-key lookups are `TABLE_SCAN`, about 1.4 ms per row, and `CREATE INDEX` is unsupported (`nosqlserver/idx.log`, `nosqlserver/idx2.log`). SSC import time therefore grows quadratically: the GA Intentions dogfood (18 files, 361 methods) took more than 20 minutes for 5 files.
- *Owner action:* index path or v0.9x evaluation. Adaptive indexes are advisory and fall BEHIND under writes.

**R-07 | CRITICAL | libxtp (ChatGPT) | oorexx_xtp_v0.1-dev25.zip (SHA-256 `7f6ab3d1167d5fd3131c7e6d6e9ea8d8c6115106ea9df89d41357ef56773b80b`)**
- *Observation:* the UDP sender reports DELIVERED on a forged close-ACK sent from a non-destination port with no listener (`xtp/neg_spoofed_ack.log`).
- *Root cause (proven by source):* `recvfrom(..., nullptr, nullptr)` with no source check on UDP, raw36 and L2. ACKs carry no authentication.
- *Expected:* a transport ACK accepted only from the route destination and, for the gateway, authenticated.
- *Architect decision:* the gateway contract (section 4).

**R-08 | HIGH | libxtp | same baseline**
- *Observation:* the L2 listener accepts and ACKs a frame addressed to a foreign MAC (`xtp/neg_l2_foreign_mac.log`, on loopback).
- *Root cause (proven by source):* no destination-MAC check.
- *Field impact:* hypothesis; it applies on promiscuous bridges with TAP members, which is the ED209 MI topology.

**R-09 | HIGH | libxtp operational adapter | same baseline**
- *Observation:* `Throttle:0` is permitted with zero delay, although the planner refuses the ticket (`xtp/neg_zero_throttle.log`). The send path never consults the operational plan, and `capacityRate(0)` means unlimited.
- *Note:* Storage Fabric dev23 itself fails closed correctly.

**R-10 | HIGH | ED209 RTO2 candidate1 (Codex/ChatGPT) | ed209_rto2_20mi_candidate1.zip (SHA-256 `6e1d33d4c6aa5a19116a3a685b7e6e05a7da6dcb8a5ed6ec3e07330034cbcb2f`)**
- *Observation:* a fabricated receipt with no MI, no XTP and no key passes `run_20mi.check_receipt` (`rto2/forge_receipt.log`). The receipt digest is self-consistency, not attribution, and responses are symmetric-key, so the MU could forge an MI result.
- *Expected:* "20/20 signed or otherwise attributable".
- *Architect decision:* an MI-held signing key, or at least retaining the raw sealed response frame per receipt.

**R-11 | HIGH | ED209 RTO2 candidate1 | bin/mu_controller_run.sh**
- *Observation:* the ooRexx submitter writes its failure reason to a temp file that is deleted on exit, and every failure becomes rc=70. All 16 controller runs on 22 Oct (per the operator's sshnode log) are rc=70 with no cause.
- *Change:* diagnostic `mu-xtp-diagnose.rex` (a read-only PROBE that classifies the guest reply). NOT TESTED: the Grid classes it needs are not in Git.

**R-12 | MEDIUM | ED209 RTO2 | crypto on guests**
- *Observation:* pure-ooRexx HMAC-SHA512 takes 0.5 s per 64 B and 5.2 s per 4 KB here (`crypto/sha_timing.log`). The halted log in candidate1 is in that code.
- *Hypothesis:* missing FAST crypto on F turns authenticated exchanges into timeouts.
- *Smallest diagnostic test:* the elapsed time in `mu-xtp-diagnose.rex`.

**R-13 | MEDIUM | Publication (Codex) | 2026-10-07 source publication**
- *Observation:* test fixture ZIPs listed in package manifests were dropped by the "no ZIP" rule; `test/fixtures/*/family.zip` was missing, so SSC's own suite could not run from Git.
- *Change:* fixtures regenerated and labelled.

**R-14 | MEDIUM | Process (ChatGPT) | autobuild submissions 2026-10-16/23**
- *Observation:* XTP dev25 and Storage Fabric dev23 are submitted `publish.artifact_only`, so their source will never reach Git even on PASS. The NoSQLServer v0.91 intake is a patch only; the README says the complete v0.79→v0.91 source is not in Git.
- *Owner action:* resubmit as `publish.tree`, and supply the complete NoSQLServer v0.91 package (SHA `d4a27600…`).

**R-15 | MEDIUM | XTP dev24(1) delivery | oorexx_xtp_v0.1-dev241.zip (SHA-256 `9599ee6fc2d8a0fb2df5285ca28c199af7782e07eb44c422690325ee7315d331`)**
- *Observation:* it ships prebuilt binaries requiring GLIBC_2.38, which matches the reported openSUSE ABI failure. dev25's `DEPENDENCIES.json` still says dev23/planner dev2 while its build uses planner dev5, and dev25's multicast test used Socket Provider dev13 while dev16 is declared.

## 3. Ten highest risks, in order

R-04, R-07, R-01, R-02, R-10, R-08, R-11, R-06, R-09, R-03.

## 4. Smallest production-correct XTP gateway contract (C2), with negative tests

1. **One process per network namespace owns every carrier listener** (L2 0x817D, raw36, UDP 62801). A second instance refuses to start. Applications register services over a local Unix socket, authenticated by peer credentials and mapped to a Service Descriptor owner. A duplicate live claim is refused.
2. **Every inbound FIRST is authenticated before dispatch.** It must be MACed or signed over header, service name, KEY, ROUTE, nonce and time window, using the commissioned per-peer key first (the existing QueueXTPWire envelope) and an Ed25519 principal signature second.
3. **Rights are checked:** principal × service × carrier × source binding.
4. **Admission comes from a Planner ticket.** The class comes from the local descriptor, never from the wire. A refused ticket or a zero rate means no transmission and an authenticated REJECT.
5. **Contexts are keyed by (carrier, authenticated principal, peer address, KEY).** A KEY collision from another principal is dropped, and DATA for an unknown or unauthenticated context is dropped.
6. **ACKs are MACed and bound to (KEY, rseq, dseq, service, peer).** A sender accepts an ACK only from the route destination with a valid MAC. A transport ACK is never an application receipt.
7. **Only live registrations with a valid provisioning lease are published.** Unpublication happens before shutdown, with a draining deadline.
8. **Fail closed** on malformed or oversize frames, an L2 destination MAC that isn't ours or a joined group, downgrade, a replayed nonce, and a second gateway.

Negative tests (three exist now: N1, N2, N8):
- N1: spoofed ACK
- N2: foreign MAC
- N3: unauthenticated FIRST for a registered service
- N4: duplicate registration
- N5: KEY collision across principals
- N6: replayed FIRST
- N7: oversize L2 frame
- N8: zero-throttle
- N9: two gateway instances
- N10: handler stdout contamination

Staged migration:
- S0: source and MAC checks behind a flag in a dev26 candidate.
- S1: the gateway on a test interface of one non-production MU.
- S2: the gateway hosts the existing QueueXTPWire handler as service `qf.xtp.rpc`, with unchanged keys and manifests, taking over one MI at a time with rollback to `qf-xtp-rpc`.
- S3: named FIRST plus authentication for new services.
- S4: `xtp.provision`, only after S3's negative tests pass in the field.

## 5. Narrow F/H experiment (C1), in order and each step gated

1. Read-only snapshot of F and H (`ed209_readonly_snapshot.sh`, through the operator's `sshnode.sh` with `--job-id`). It needs no approval beyond running it.
2. Diff the edited `mu-rto2-submit.rex` (hash `c385de93…`) that was pushed to F on 22 Oct against delivered candidate1 (`4fbfeab0…`).
3. On F's MU: one `mu-xtp-diagnose.rex` PROBE using a known-good existing peer row. If that passes, one PROBE using the `grid-controller` row. One cause is isolated per run. *Approval needed:* this sends one packet to a guest.
4. Only then repair, for one MI, the first classified cause. Then the second F MI, then H. The 4/4 gate means `500500` receipts with the raw sealed response retained.

## 6. Where I disagree, and what would change my mind

- **"Transport ACK" is not evidence of delivery in libxtp, even locally.** It changes when ACKs are source-bound and MACed (N1 passes).
- **The 20/20 gate as written in candidate1 can't produce attributable receipts.** It changes with an MI-held signing key, or retained sealed frames plus a key-holding auditor.
- **NoSQLServer v0.79 shouldn't back SSC at estate scale.** It changes when a v0.9x run of `test_live/` and the dogfood shows indexed key access and correct UPDATE literals.
- **ChatGPT's SSC readers are not "complete with tests"; they had never run.** That's settled by `ssc/live_suite.log`. It would change only with evidence of a real-database run before today.

## 7. Contents of this directory

- `autobuild/` — v0.5 start reproduction; rehearsal intake and mirror logs; pending backlog
- `ssc/` — live suite log for store dev26
- `nosqlserver/` — fidelity, UPDATE, INSERT, predicate and index probes with logs
- `oorexx/` — RESULT-variable trap, ooRexx house-rules verification, SQL rewrite unit test
- `crypto/` — pure ooRexx vs Foreign Runtime SHA timing
- `xtp/` — dev25 build/test logs, three adversarial tests with logs
- `rto2/` — forged-receipt probe
- `ed209/` — read-only snapshot job, PROBE diagnostic, Claude Code instructions
- `autobuild_install/` — Claude Code install guide for v0.5.1

Claude (Opus 5.5)

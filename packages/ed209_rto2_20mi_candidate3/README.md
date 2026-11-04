# ED209 — RTO2 small-job runner (20 MIs), candidate1

This is an executable **one bounded job per Mesh Instance** acceptance harness, with an authenticated XTP return to the **owning MU controller**, a real `alchemy.rto/0.1` captured/locally committed state, an immutable MU-local receipt, and centrally sorted results. The work is `sum(1..1000) = 500500` on each MI. This is not 20 SSH shell jobs.

**Not a declaration of field success:** the source package and existing F/H working images have not been remotely changed. The MI work handler is an additive staged guest-image change requiring rollout; the older eight MUs may have no running MIs. A 20/20 fixture test is synthetic; no live 20/20 was observed here.

## Run from central controller/operator workstation

```bash
# First check that the target set is the correct 20 commissioned MI IDs.
SSHNODE=./sshnode.sh bash bin/run_all_20.sh ED209-SMOKE-1 --dry-run

# After EACH owning MU and MI has the staged work service installed and qualified:
SSHNODE=./sshnode.sh bash bin/run_all_20.sh ED209-SMOKE-1

# Pilot only (not full-estate evidence):
SSHNODE=./sshnode.sh bash bin/run_all_20.sh ED209-PILOT-HF --only ed209f ed209h
```

A successful full run writes `ed209-rto2-runs/RUN_ID/summary.json`, `results_by_route.csv` and `results_by_value.csv`. Missing or duplicate MIs, mismatched epochs, incorrect computed values, no controller commit or invalid content digests cause failure. Each assigned route 1..20 must have exactly one result.

## How it really moves

```
central runner --sshnode (operator control to owning MU only)
    -> owning MU's mu_controller_run.sh
    -> authenticated qf-xtp-rpc client (XTP L2, NOT SSH to guest)
    -> guest qf-xtp-handler.rto2.rex [manifest-bound controller authority]
    -> real RTO2CountJob ACTIVE assignment from trusted controller, commitLocalValue,
       AlchemyRTO.capture() with detached state
    <- authenticated QueueXTPWire response carrying the RTO2 captured result
    -> MU validates identity, role, epoch and committed state, fsyncs immutable receipt
    <- sshnode returns MU controller's durable receipt (OPERATIONAL observation only)
    -> central CSV/JSON deterministic sort by route and value
```

There is no role-election shortcut; the controller explicitly supplies the test activation epoch. This is an RTO2 **local capture and commit**, not an HA mirrored replay or Job-to-Node allocated production job. It does not claim inter-MU Queue Fabric application dispatch, WAN XTP forwarding, or independent cryptographic proof at the central sorter. The sorter relies on the authenticated MU control session plus locally verified XTP response and on-disk receipt.

## Commissioned authority and service limitations

- Do not copy one MU's keys to another; use each MI's actual `node.env` and the correct MU's MAC and route.
- The RTO2 work key is a separate HMAC-SHA256 context-derived subkey from the MI's existing registration key. It is *not* the registration key reused as an application secret.
- A private, additive manifest row with `grid-controller` principal and `RTO2.<MI>` receiver channel must be staged in that MI's next image. No live production manifest is edited automatically.
- `ops/stage_grid_overlay.py` produces a separate build tree, not an in-place modification. Merge with F/H's **actual working handler/bootstrap revisions**, especially the earlier FAST and retry corrections, before building a guest.
- This harness uses the existing proven Grid `qf-xtp-rpc` wire adapter. **It does not implement or qualify native dev24 named-service FIRST/KEY semantics**; that transition must be integrated with an authentic Service Descriptor Registry binding before claiming latest-XTP full installation. `RTO2.<MI>` is a Queue Fabric receiver-channel name, **not** an invented canonical XTP service descriptor.
- No persistence beyond the MU-local controller result files or WAN federation is claimed. No service activation, firewall changes or credential regeneration occurs from the fleet runner itself.

## Source package contents

- `bin/run_all_20.sh`, `bin/run_20mi.py`: central job campaign and sorter.
- `bin/mu_controller_run.sh`, `rexx/mu-rto2-submit.rex`: authenticated native XTP MU-to-MI controller invocation.
- `rexx/qf-xtp-handler.rto2.rex`: narrowly extended guest handler; preserves existing PROBE and DELIVER paths and repairs a special-variable collision in the registration snapshot writer.
- `rexx/rto2-smoke-local.rex`: isolated executable ooRexx RTO2 count job for qualification.
- `bin/controller_commit.py`: immutable, synchronised controller result publication and validation.
- `ops/stage_grid_overlay.py`, `ops/stage_mi_controller_trust.py`: non-destructive build staging.
- `ops/derive_work_key.py`: domain-separated per-MI test key derivation from private commissioning material.
- `tests/`: real ooRexx request/response test, Python acceptance and negative tests.

See `docs/CODEX_EXECUTION.md` for deployment and exact commands.

## Candidate2 F return-envelope repair (2026-10-22)

Field failure: XTP native transaction completed, but MU could not decode the returned bytes as an authenticated `QFXTP` response. Locally reproduced the exact error class against a guest missing its `grid-controller` grant: it returned plaintext `UNAUTHENTICATED:PEER_NOT_TRUSTED`, which the old client reported as `XTP_FRAME_INVALID`. Live F's precise cause still requires **inspection of its booted cpio**, not just installed source.

Corrections: symbolic `GRID.MN.<MI>` route lookup, redacted transport-response classification, additive patch to preserve local FAST/envelope fixes, exact guest cpio inspection of RTO2 permissions and runtime startup flags, and an image builder that refuses to clone a commissioned MI image. Source and private commissioning authority are **never changed in place**.

See **`docs/CODEX_FIX_F_RESPONSE.md`** for the staged field repair, acceptance and rollback steps. The fix is tested locally, not yet installed/verified on F or H. Do not count 20/20 until each actual MI has returned a committed controller receipt. The dev25 named-service migration is a separate work item; this fix remains on the established segmented Grid XTP link for compatibility with the running estate.

## Candidate3 R-11 typed errors

Owning MU preserves native exit status and emits a fixed redacted failure class; untrusted guest bytes are not logged. It does not prove live ED209 20/20, MI-held signature attribution (R-10), or XTP dev30 FIRST/KEY/DATA adoption. See `docs/CANDIDATE3_R11.md`.

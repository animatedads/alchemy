# Codex: run the 20-MI RTO2 execution smoke campaign

## Acceptance objective

20 distinct MI identities must each execute `sum(1..1000)` **inside the guest** and return the detached `AlchemyRTO` captured/committed state over authenticated XTP L2 to the **owning MU**. The MU must durably publish one immutable receipt. The designated central operator/controller must gather those receipts and emit route-ordered and value-ordered CSV plus JSON. **No success claim from SSH, QEMU process counts or Queue Fabric transport-delivery ACKs alone.**

The allocated route order is A(1/2), B(3/4), C(5/6), D(7/8), E(9/10), I(11/12), J(13/14), K(15/16), F(17/18), H(19/20). These are the previous append-only Grid allocations; on each machine verify against the authoritative `node.env` and reject conflicts.

## On the deployment workstation

```sh
unzip ed209_rto2_20mi_candidate1.zip
cd ed209_rto2_20mi_candidate1
SSHNODE=./sshnode.sh bash bin/run_all_20.sh ED209-SMOKE-1 --dry-run
```

## Stage on each MU and its MIs, starting with F/H

1. Use **existing** `sshnode.sh` transfer and local approved Grid installer. Copy package to `/opt/rexxos/rto2-smoke`. Preserve owner/MAC/TAP setup, kernel, keys and images. Do not overwrite active images.
2. Build a new working-source **staging copy**, resolving the actual *installed* F/H Grid source revision first:

```sh
python3 ops/stage_grid_overlay.py \
  --grid /opt/rexxos/grid-accepted-source \
  --output /root/rexxos-private-stage/grid-rto2-smoke
```

The overlay replaces the guest Queue/XTP handler, adds `RTO2CountJob`, `AlchemyRTO`, `AlchemyClusteredApp` to the initramfs and sets `GRID_NODE_ID`, `GRID_MU_ID`, `QF_XTP_RTO2_ENABLED` for that handler. It does **not** replace the XTP native helper or install any image. If the source has moved, resolve the conflicts; do not bypass source guards.

3. For each commissioned MI, produce a private additive peer manifest (example H):

```sh
python3 ops/stage_mi_controller_trust.py \
  --authority /etc/grid/commissioning \
  --mi MN1-ED209H \
  --output /root/rexxos-private-stage/MN1-ED209H-rto2-peers.manifest
```

The resulting `grid-controller` row is bound to the owning MU ID and MAC, one MI, one RTO2 receiver channel, and a distinct derived work key. The file contains secrets and must remain `0600` in a `0700` root-only directory. Existing peer and registration entries are preserved. The script refuses to modify an existing output. Repeat for MN2.

4. Rebuild the two guest images from the accepted authority **using the staged manifest for each corresponding image** and the preserved commissioning MI identity; qualify FAST, registration, heartbeats, and ordinary peer probes before the RTO2 work request. Stage one MI at a time and preserve the working F/H rollback. Do **not** copy H-local test credentials into a different MU or promote H's local-test trust to production federation.
5. On each MU, install the complete `bin/`, `rexx/`, `ops/` package, set approved runtime/dependency paths from that host's known-working Grid package, and create a root-owned `/etc/rexxos-grid/rto2-test.env` with only nonsecret deployment paths, for example:

```sh
GRID_AUTHORITY=/etc/grid/commissioning
GRID_PACKAGE_ROOT=/opt/rexxos/grid-accepted-source
GRID_RTO2_APPROVED_EPOCH=1
```

Use the **actual** installed source location and approved RTO2 test epoch. Never copy this literal example blindly. Optional `GRID_RTO2_STORE` selects a different MU-local result store. `bin/mu_controller_run.sh` runs on the owning MU under an account permitted to read its private commissioning records and commit to its result directory; the central `sshnode.sh` account may need `sudo -n` via a strictly approved command wrapper. Do not enable arbitrary root shell execution.

6. Prove the guest's live authenticated work path from its owning MU:

```sh
# Only AFTER guest handler and trust have been installed:
/opt/rexxos/rto2-smoke/bin/mu_controller_run.sh ED209-PILOT-H MN1-ED209H 1000
```

The output should be exactly one `ed209.rto2.controller-receipt/1` JSON object with a committed state and a matching local receipt file. The MI must run under QEMU; the MU must not run the calculation on behalf of the guest. Verify that failed transports and negative grant tests do not commit receipts.

7. From the designated **central** operator/controller machine:

```sh
SSHNODE=./sshnode.sh \
  bash bin/run_all_20.sh ED209-PILOT-HF --only ed209f ed209h

SSHNODE=./sshnode.sh \
  bash bin/run_all_20.sh ED209-FULL-001
```

Sort files: `ed209-rto2-runs/ED209-FULL-001/{summary.json,results_by_route.csv,results_by_value.csv}`. The full gate requires **20/20 distinct actual MI execution receipts**; 19/20 is failed, not nearly accepted. Since H has one vCPU, work is deliberately sequential within each MU.

## Limits of this candidate

- `RTO2CountJob~commitLocalValue` plus `AlchemyRTO~capture` is real local RTO2 state/commit. It does **not** prove mirrored replay, signed failover epoch, allocator lease or a durable cross-MU RTO2 federation.
- The work response is returned from an authenticated MI through `QueueXTPWire`, directly to its owning MU, **not** as a Queue Fabric persistent queue transfer. That distinction must be preserved. Receipt fsync+rename on the MU is a local publication contract.
- The operator uses SSH **only** to invoke the already deployed MU controller service and collect its durable output. There is no SSH execution inside an MI. Central sorting uses this operational readback channel; migrating it to WAN Queue Fabric is a separate acceptance stage.
- This exact XTP CLI adapter is based on the working segmented Grid helper, which still uses dev18 packet services. It has **not** been reconciled with native dev24 named-service FIRST and persistent DATA. Before claiming a **latest-XTP full installation**, install the authorised canonical RTO2 service descriptor and bind it through the dev24 adapter/ConnectSelector, then independently prove FIRST → admission → KEY/DATA over L2, raw36 and UDP 62801. No example service identity may be promoted as authoritative.
- The core of the test is a small runnable job and a strict result sorter; no live hosts were contacted while building it. The all-20 simulated fixture is **not live evidence**.

## Tests

```sh
ED209_GRID_SOURCE=/path/to/candidate3/grid \
ED209_REXX=/path/to/ooRexx/bin/rexx \
ED209_REXX_LIB=/path/to/ooRexx/lib \
  bash tests/native_wire.sh
python3 -m unittest discover -s tests -p 'test_suite.py' -v
```

Use one accepted upstream Grid baseline for build comparison. `tests/native_wire.sh` runs a real authenticated controller-work-handler exchange with a **disposable fixture key**. Extended negative crypto tests are opt-in with `ED209_EXTENDED_CRYPTO_TESTS=1` because the source tree's software HMAC fallback can take an unreasonable duration. Native fast crypto on the deployed MI is an independent field gate.

# Codex: F RTO2 controller response fix — stage, inspect, execute

## What is actually proven

Candidate1's controller looked up the XTP route using the MI's MAC; the accepted route uses `GRID.MN.MN1-ED209F` or `GRID.MN.MN2-ED209F`. This package fixes the lookup. A successful XTP transport transaction is **not** evidence that the guest returned a valid authenticated Queue Fabric response.

The local executable reproducer proves that the original guest handler responds with plaintext `UNAUTHENTICATED:PEER_NOT_TRUSTED` when the `grid-controller` entry is missing. This reproduces the `XTP_FRAME_INVALID` failure **class**, not its exact cause on ed209f. The corrected controller classifies this failure as `RTO2_MI_CONTROLLER_GRANT_ABSENT_OR_STALE` without echoing raw, possibly malicious bytes.

## Step 1 — verify the deployed image (read-only, no secrets in output)

On `ed209f`, find the precise image used by the running QEMU process with the normal `sshnode.sh` operator command and approved host service configuration. Do not guess from source-tree filenames. Invoke the bundle's verifier against that file:

```sh
python3 /opt/rexxos/rto2-smoke/ops/verify_guest_rto2.py \
  --authority /etc/grid/commissioning \
  --mi MN1-ED209F \
  --image /path/to/actual-running-MN1-initramfs.cpio
```

Repeat for MN2 with its own **actual** image. The verifier reads cpio entries and private `node.env` but only prints a redacted pass/fail. Required: registered MI identity, MU MAC, route, RTO2 handler, RTO2 classes, guest init `QF_XTP_RTO2_ENABLED`, and **one** correctly derived `grid-controller` grant in the guest's embedded `/etc/grid/peers.manifest`. Old running images without this grant will be rejected. Do not edit the live image, its private keys, or live peer trust in place.

## Step 2 — make a corrected, additive staging tree

Use the **actual installed F working Grid source**, including F's FAST crypto and Queue Transmission Envelope registration fixes. The overlay now inserts only the RTO2 branch and the required classes. It does not overwrite F's entire live Queue Fabric handler.

```sh
python3 /opt/rexxos/rto2-smoke/ops/stage_grid_overlay.py \
  --grid /path/to/installed-and-verified-working-F-Grid-source \
  --output /root/rexxos-private-stage/grid-f-rto2-candidate2
```

Inspect the `RTO2_SOURCE_MERGE_RECEIPT.txt` hashes. Any unrecognised source shape fails closed rather than discarding a host-specific fix. Use this same verified Grid tree for the helper and guest image; preserve `ed209f`'s working segmented L2 return path. No changes to WAN forwarder or firewalls.

## Step 3 — build the MN1 candidate and test it without replacing the running service

Select the accepted, **generic uncommissioned** base initramfs, the verified static BusyBox and the actual approved incarnation string. The script takes the keys **only from the existing installed private F authority**, creates an additive controller trust manifest, invokes the established guest image builder, then verifies the built cpio itself. It refuses to copy a commissioned guest as a base image.

```sh
python3 /opt/rexxos/rto2-smoke/ops/build_mi_rto2_image.py \
  --grid /root/rexxos-private-stage/grid-f-rto2-candidate2 \
  --authority /etc/grid/commissioning \
  --mi MN1-ED209F \
  --base /path/to/clean-accepted-base.cpio \
  --busybox /path/to/verified-static-busybox \
  --incarnation ACTUAL_APPROVED_MN1_INCARNATION \
  --output /root/rexxos-private-stage/MN1-ED209F-rto2-candidate2.cpio
```

`ACTUAL_APPROVED_MN1_INCARNATION` is a placeholder: resolve it from the installed authority. Build an **isolated** test instance on a separate TAP/safe commissioning setup using the established `run_grid_mi_qemu.sh` and proven F test procedure; do not run a second guest with the same MI identity on the live bridge. If isolation cannot preserve unique identity, quiesce that *one* MI under the existing rollback procedure and test the replacement in its assigned slot. Leave MN2 and the MU service available.

Perform guest FAST crypto, registration/heartbeat, normal PROBE/peer regression, and then RTO2 work. No reboot-persistent promotion until all pass. The committed result must have `value=500500`, `committed_sequence=1`, the correct epoch and a non-fabricated `alchemy.rto/0.1` capture.

```sh
/opt/rexxos/rto2-smoke/bin/mu_controller_run.sh ED209-F-C2-MN1 MN1-ED209F 1000
```

Only after MN1 produces an immutable receipt should MN2 be rebuilt and tested similarly. Re-run both and then H (H's local-test authority remains test-only). Do not attempt the remaining sixteen MIs until F's real controller receipts pass.

## If an error remains

- `RTO2_MI_CONTROLLER_GRANT_ABSENT_OR_STALE`: the MI handler has no `grid-controller` row; verify the actual *booted* archive, not the source manifest.
- `RTO2_MI_UNAUTHENTICATED_REJECTION`: pre-auth denial; inspect guest handler **stderr** and request/manifest match. Never promote plaintext response to an authenticated receipt.
- `RTO2_MI_RESPONSE_NOT_QFXTP bytes=N`: check the guest's actual handler version, ooRexx exceptions and stdout contamination; the byte length is reported but untrusted content is not echoed.
- `XTP_RESPONSE_AUTH_FAILED XTP_SECURE_AUTHENTICATION_FAILED`: the wire is a valid QFXTP envelope but the controller/MI **key or authenticated header** differs; check exact derived subkey and channel bindings.
- `RTO2_REMOTE_REJECT CODE`: the authenticated guest denied work; investigate that specific code.
- `XTP_TRANSACTION_FAILED`: transport-level issue; verify commissioned symbolic route resolves to F's correct MAC and TAP, ACK and response delivery, and both helper versions.

**Never** use a transport success or a plaintext rejection to publish a controller receipt. Retain original binaries, keys and images for rollback. Test output and manifests must not expose private keys.

## Local tests

```sh
python3 -m unittest discover -s tests -p 'test_guest_preflight.py' -v
python3 -m unittest discover -s tests -p 'test_overlay.py' -v
python3 -m unittest discover -s tests -p 'test_suite.py' -v
ED209_GRID_SOURCE=/path/to/staged-grid ED209_REXX=/path/to/rexx ED209_REXX_LIB=/path/to/lib \
 bash tests/native_wire.sh
ED209_GRID_SOURCE=/path/to/staged-grid ED209_REXX=/path/to/rexx ED209_REXX_LIB=/path/to/lib \
 bash tests/native_controller_rejection.sh
```

Acceptance is **live 4/4 F+H receipts, then 20/20 all MIs**; neither milestone has been demonstrated by this package alone. This candidate still uses the commissioned segmented Grid transaction adapter (dev18 wire implementation); XTP dev25 service-first migration is a distinct unqualified boundary, not silently claimed by this fix.

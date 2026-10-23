# RexxOS Virtual UPS — LLM Gopher continuity sphere v0.2

**Proposed sphere ID:** `rexxos-virtual-ups` (not registered with runtime Gopher)
**Owner:** legacy computing / power simulation lane
**Date:** 2026-10-23
**Status:** SOURCE_CANDIDATE, reference tests qualified, guest adapter NOT QUALIFIED

## Semantic authority

A simulation of electrical mains, energy storage, load and charge state for
research. Synthetic effects only. Source-owned power simulation is separate
from historical guest OS evidence, live RexxOS power state and cloud-provider
power controls. Logical simulation time is not UTC; time conversion belongs to
Single Time Service after its transport-neutral API is qualified.

## Evidence correction

The TOPS-20 `Waiting for UPS:` console message appears under PTYCON
`MAILS`/`OPR`; pinned KLH10 `doc/klt20.txt` attributes recurring message to
an `MX` process. Its acronym expansion, mail delivery behavior, and electrical
relationship are **UNRESOLVED**. Operator suspects an email error. Preserve
this as an hypothesis, not a fact. Do not bind these logs as hardware events.

## Implemented v0.2 candidate

- `virtual.ups.state/1`, `virtual.ups.signals/1`, `virtual.ups.event/1`,
  replay-verified `virtual.ups.journal/1`, `virtual.ups.snapshot/1`.
- Single-user, local stdio JSON-RPC 2.0; mutations opt-in and not remote-authorized.
- Logical-time deterministic battery discharge/recharge and threshold events.
- `virtual.ups.guest-observation/1`: read-only TOPS-20 diagnostic text
  classification, fail-closed interpretation; unrelated to simulation state.
- Canonical JSON, reject duplicate keys/nonfinite constants; basic journal
  consistency chain. Journal hash is not an authenticated signature.
- 17 Python unittest tests qualified on package authoring host.

## Integrations: candidates only, not delivered

- Native ooRexx semantic service without making Python a runtime dependency.
- Connect Selector direct local / JSON-RPC / Queue Fabric optional adapters;
  no invented selector API or Queue Fabric authority transfer.
- Instrumentation Mesh event projection as observation only; source of truth
  stays UPS journal and synthetic state.
- Single Time Service for optional independent UTC correlation; logical tick
  remains primary simulation clock.
- RexxOS MI/MU portable job / Storage Fabric named artifact snapshots (no
  implicit migration or host-local paths in portable work descriptions).
- DEC/TOPS-20 power-fail signaling after authoritative guest/DEC source
  qualification; no guest live power injection yet.

## Safety boundaries

No real OS halt, reboot, host power action, UPS controller, email transmission,
cloud API, guest disk writes or network listener. State path must be local,
private and user-owned. Untrusted console capture is observation, not authority.

## Source and provenance

- Executable/reference package `packages/rexxos_virtual_ups_v0.2`.
- KLH10 guide pinned source SHA:
  `6d733f2a47644964492fd864454cbe1331655e53`.
- User-supplied 2026-10-15 TOPS-20 trace and reports from ed209j;
  this artifact does not claim to have fetched live host logs.
- User Library reviewed: `PA-STK-TIME_Time_and_Temporal_Semantics.pdf`,
  `PA-STK-OBS_Instrumentation_and_Observability.pdf`,
  plus existing Alchemy GitHub Gopher sphere conventions.

## Next gates

1. Inspect authentic MX scheduler/source to resolve `UPS` meaning.
2. Independently qualify ooRexx port against Python golden traces.
3. Verify Connect Selector and Instrumentation Mesh package versions/APIs.
4. Design DEC power device adapter only after hardware specification and
   controlled host isolation; do not touch installed TOPS-20 disk.
5. Record explicit storage, migration, authorisation and fail-closed policies.

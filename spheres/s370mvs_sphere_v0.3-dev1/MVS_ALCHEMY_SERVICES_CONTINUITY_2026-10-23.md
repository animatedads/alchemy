# MVS Alchemy Services — continuity and qualification boundary (updated 2026-10-24)

## Scope and authority

This note augments the GitHub-resident `s370mvs` sphere. It does **not** change
the sphere's System/370 instruction evidence, sealed safety checkpoints or emulator
qualification claims. MVS Alchemy Services (MAS) is a separate consumer of the
emulator/native MVS environment.

The project coordinator currently resolves an external/local `s370mvs` override at
version `0.6-dev1`, archive SHA-256
`fdb9bc7060f7631b6f814c288786f6fbfc3d949cb5cb7eaa23341b3762bb051a`.
That override is not present in GitHub and could not be resolved through the Semantic
Source Store during this reconciliation. This file is therefore the repository
continuity record; it does not pretend GitHub contains the external v0.6 override.

## Current MAS source and artifact

Current reconciled development artifact:

- `mvs_alchemy_services_v0.1-dev3-pre22-current-contracts.zip`
- SHA-256 `3f3bed3da3f9a412de1a69f49e095382c81cfca91312c330c775bbe9afa128ea`
- repository source:
  `packages/mvs_alchemy_services_v0.1-dev3-pre22-current-contracts/`

The repository tree contains the exact PRE22 source/tests/tools/specification and
qualification members imported from the local package tree, except dependency ZIPs
under `reference/`, which remain external and are pinned by SHA-256. The exact ZIP
remains immutable delivery authority and Git publication is not itself a live MVS pass.

## Current contract reconciliation

Reviewed inputs:

- ConnectSelector dev6 — `6ea919552264a8d50db77b2a513990226a869ebbf3ed930e98c055c8175184ae`
- RPC Portfolio dev1 / RpcServiceCore dev1 — `c07d87ebfdaf988ad9a4c2a4e52a8927da29b4e40365fbc7bd0fd544fa7a66fc`
- Instrumentation Mesh dev8 — `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`
- SerializationSelector v0.5 — `410c152e2771d55ce567cb79d76ca48e49190c39fa580767252d5d9d5a5ada37`
- SMTP Secure Stack dev11 — `95bf988357505e2ab59ec3264d702e9179c99be530cb55248647cf23ac3229bc`
- NoSQLServer v0.91 guarded SQLite candidate — `d4a276007029e66512611ea7e836ca7ab30209b80ac7d46ecf1fba61121f02d0`
- LDAP Identity dev19 candidate — `14d41d9c1cd339ccd99bc1a344b182fdb86ef2b5c30ee6454dd2fbfe1525d8ec`

NoSQLServer v0.91 and LDAP dev19 remain development candidates with their upstream
qualification caveats; MAS must not silently promote them.

## Architectural repair

PRE21 carried a MAS-local `MasRpcCoreConnector`. ConnectSelector dev6 already owns
the qualified `ConnectRpcDispatchAdapter` around `RpcServiceDispatcher`; PRE22
removes the duplicate MAS adapter. MAS publishes an explicit operation allowlist
through `MasRpcServicePublisher`.

Authority remains separated: MAS owns MVS-visible semantics/provider composition;
RpcServiceCore owns registered dispatch; ConnectSelector owns route admission and
uncertain-outcome behavior; JSON-RPC/SOAP/gRPC bindings own protocol envelopes;
SerializationSelector owns representation/schema; Instrumentation Mesh owns
operational observation; Logging v0.7 owns correlated qualification/audit evidence.

The Queue personality remains deliberately unmapped to generic enqueue because MAS
QPUT/QGET/QDEPTH have synchronous reply semantics stronger than an enqueue receipt.

## Qualification truth

PRE22 static reconciliation passed RPC/selector alignment, security/identity checks,
Instrumentation Mesh wiring, HASP shell safety, ASCII `ALCH` wire checks, 22 typed
payload checks, harness shell syntax, assembler/JCL width checks and dependency hashes.

Host runtime integration was **not rerun** during the 2026-10-24 reconciliation
because the required project r13196 runtime was not available in this working
container. PRE21 runtime results remain historical only.

PRE22 is **NOT_RUN live on ED209Z**. PRE12 remains the last recorded live guest
execution attempt: assembly/link progressed and RUN abended S0C4 at X'75'; no guest
request reached the gateway. Subsequent carrier fixes remain unproven until an
unchanged current package runs through JES.

## Identity and authority

Production identity comes from a host authentication/attribution boundary. Guest
user/session IDs, transport address, or guest VERIFIED/AUTHORIZED/EGRESS booleans
do not grant authority. MAILSIGN/MAILSEND require host-attributed principal
authority; signing material never crosses into the guest.

## Next acceptance slice

1. Re-run PRE22 host tests under exact ooRexx 5.3.0 r13196 and pinned dependencies.
2. Submit the unchanged PRE22 archive through the established ED209Z JES path.
3. Preserve first-failure JES spool, Hercules window, Logging v0.7 and Mesh evidence.
4. Prove X'75' crossing and a harmless request before expanding live mutation/provider coverage.
5. Keep ED209Z and ED209ZZ qualification evidence separate.


## PRE23 JES completion/spool gate (2026-10-27)

PRE23 supersedes PRE22 for qualification runs without changing the MVS carrier, wire, RPC, provider or authority semantics. The PRE22 harness could observe `MASLIVE PASS ALL` and proceed to final PASS without independently requiring JES2 `$HASP395 MASLIVE ENDED`. PRE23 closes that evidence gap.

Current artifact: `mvs_alchemy_services_v0.1-dev3-pre23-jes-completion-gated.zip`, SHA-256 `4b7f92672b9675d2b508cef6dbda7b01fc44a381057044304cbdf269ba783b7f`.

A live PASS now requires, in order: facility completion, `$HASP395 MASLIVE ENDED`, retained final MASLIVE printer/spool evidence, then the existing Logging v0.7 and Instrumentation Mesh evidence checks. `PASS ALL` without HASP395 is INCONCLUSIVE. HASP395 without retained MASLIVE spool is also INCONCLUSIVE. PRE23 remains NOT_RUN live on ED209Z until the unchanged sealed archive is exercised through the established JES path.

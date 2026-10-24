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
- repository source projection:
  `packages/mvs_alchemy_services_v0.1-dev3-pre22-current-contracts/`

PRE22 replaces the PRE21 host dependency assumptions with current reviewed project
contracts. The exact ZIP remains immutable artifact authority; the Git tree is a source
projection and is not itself a new live mainframe qualification.

## Current contract reconciliation

Reviewed inputs:

- ConnectSelector dev6 — SHA-256
  `6ea919552264a8d50db77b2a513990226a869ebbf3ed930e98c055c8175184ae`
- RPC Portfolio dev1 / RpcServiceCore dev1 — SHA-256
  `c07d87ebfdaf988ad9a4c2a4e52a8927da29b4e40365fbc7bd0fd544fa7a66fc`
- Instrumentation Mesh dev8 — SHA-256
  `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`
- SerializationSelector v0.5 — SHA-256
  `410c152e2771d55ce567cb79d76ca48e49190c39fa580767252d5d9d5a5ada37`
- SMTP Secure Stack dev11 — SHA-256
  `95bf988357505e2ab59ec3264d702e9179c99be530cb55248647cf23ac3229bc`
- NoSQLServer v0.91 guarded SQLite candidate — SHA-256
  `d4a276007029e66512611ea7e836ca7ab30209b80ac7d46ecf1fba61121f02d0`
- LDAP Identity dev19 candidate — SHA-256
  `14d41d9c1cd339ccd99bc1a344b182fdb86ef2b5c30ee6454dd2fbfe1525d8ec`

NoSQLServer v0.91 and LDAP dev19 remain development candidates with their upstream
qualification caveats. MAS must not silently promote them to production-certified
dependencies.

## Architectural repair

PRE21 carried a MAS-local `MasRpcCoreConnector`. Current ConnectSelector dev6
already owns the qualified `ConnectRpcDispatchAdapter` around
`RpcServiceDispatcher`; PRE22 removes the duplicate MAS adapter. MAS now publishes
an explicit operation allowlist through `MasRpcServicePublisher`, while:

- MAS owns MVS-visible service semantics and provider composition;
- RpcServiceCore owns registered service/operation dispatch;
- ConnectSelector owns route admission/selection and uncertain-outcome behavior;
- protocol bindings own JSON-RPC/SOAP/gRPC envelopes and faults;
- SerializationSelector owns representation/schema;
- Instrumentation Mesh owns operational observation;
- Logging v0.7 remains correlated qualification/audit evidence.

The RPC portfolio records shared-object SOAP/JSON dispatch through RpcServiceCore.
This does not make SOAP/JSON/gRPC mandatory dependencies of MAS, nor does it establish
production network authentication or all streaming/callback modes.

The MAS Queue personality remains deliberately unmapped to generic Queue enqueue:
`QPUT` returns depth and `QGET/QDEPTH` require synchronous replies. A Queue
request/reply profile needs explicit correlation, reply destination, expiry and
uncertain-outcome semantics before that mapping is valid.

## Qualification truth

PRE22 static reconciliation passed:

- RPC Core / ConnectSelector alignment;
- ConnectSelector security/identity checks;
- Instrumentation Mesh wiring checks;
- HASP shell-safety check;
- exact ASCII `ALCH` wire-eye check;
- 22 typed guest payload checks;
- `bash -n` on the live qualification harness;
- MASD75 and MASLIVE card-width checks;
- generated MASLIVE JCL width checks;
- exact dependency archive SHA-256 checks.

Runtime host integration was **not rerun** during the 2026-10-24 reconciliation
because the required project r13196 runtime was not available in this working
container. PRE21 runtime results are historical evidence and are not promoted to
PRE22.

PRE22 is **NOT_RUN live on ED209Z**. PRE12 remains the last recorded live guest
execution attempt: guest assembly/link progressed, then RUN abended S0C4 at the
X'75' path and no guest request reached the gateway. Subsequent carrier fixes remain
unproven until an unchanged current package runs through JES.

## Identity and authority

Production identity must come from a host authentication/attribution boundary.
Guest user ID, session ID, transport address or guest-supplied VERIFIED/AUTHORIZED/
EGRESS booleans do not grant authority. MAILSIGN and MAILSEND require host-attributed
principal authority; host signing material never crosses into the guest.

## Next acceptance slice

1. Re-run PRE22 host tests under the exact ooRexx 5.3.0 r13196 runtime and current
   pinned dependency roots.
2. Submit the unchanged PRE22 artifact through the established ED209Z JES path;
   do not IPL/reconfigure merely to run the qualification.
3. Preserve first-failure JES spool, Hercules window, Logging v0.7 evidence and
   Instrumentation Mesh evidence before source modification.
4. Prove X'75' crossing and a harmless semantic request before extending live
   mutation/provider coverage.
5. Keep ED209Z and ED209ZZ evidence separate; never merge their qualification.

# MVS Alchemy Services — continuity and qualification boundary (2026-10-23)

## Scope and authority

This note augments the existing `s370mvs` sphere. It does **not** change its System/370 instruction evidence, sealed safety checkpoints, or emulator qualification claims. The MVS Alchemy Services (MAS) host/guest service boundary is a separate consumer of the emulator and its native guest environment.

Library source inspected: `mvs_alchemy_services_v0.1-dev3-pre21-rpc-core-alignment.zip` (development candidate). Repository also contains the historical `autobuild/mvs-alchemy-services-20260924.json` for pre1; pre1 is not an authoritative current head. The pre21 archive contains `HOST/src/MasRpcServiceBinding.cls`, `HOST/src/MasConnectSelectorBinding.cls`, `HOST/src/MasLiveGateway.cls`, `mvs/asm/MASD75.asm`, `HOST/tests/mas_rpc_service_core.rex`, `HOST/tests/mas_connect_selector.rex`, `scripts/check_rpc_core_alignment.py`, and `QUAL/PRE21_STATIC_QUALIFICATION.txt`.

## Architecture

Plan42 identifies semantic requirements; the established Runtime Registry owns capability resolution and exact implementation selection. MAS owns mainframe-specific service semantics and host/guest protocol. RPC Service Core owns registered service/operation dispatch; ConnectSelector owns choice of direct call, RPC, Queue Fabric or RTO2 according to their independently qualified contracts. Serialization Selector owns codec choice and preserves protocol envelope distinctions. Transport adapters do not acquire business authority by carrying a request.

The pre21 package embeds reference archives for RPC Service Core dev1 and ConnectSelector dev2. Library observation on 2026-10-09 found ConnectSelector dev3, Serialization Selector v0.5-sint32, and RTO2 Grid dev14; their presence does not establish compatibility with the embedded pre21 dependencies. Verify exact archive hashes, APIs, runtime versions, route policy and failure semantics before rebinding.

## Qualification truth

PRE21 contains static/host qualification records, not a new live guest qualification. Earlier guest X'75' evidence is not upgraded by subsequent host-side alignment checks. Keep assembler, JCL, JES, transport framing, guest response, correlation and failure classification as independent gates. A package must not claim end-to-end live MVS qualification until the target guest is exercised and the exact evidence is retained. Preserve the 2026-10-05 MAS provenance reset; the historical dev2 guest implementation claim was invalidated.

The MVS service's production identity must come from a host authentication/attribution boundary. Guest user ID, session ID, transport address, TLS, or guest-supplied boolean flags alone do not grant permissions. For MAILSIGN and MAILSEND specifically, see `packages/oorexx_smtp_secure_stack/MVS_PRE17_INTEGRATION.md`: signing is distinct from authorization to send, and host signing key material must not be handed to the guest.

## Next acceptance slice

1. Pin the exact RPC Service Core, ConnectSelector and Serialization Selector dependencies; validate source API and no-fallback-after-uncertain-execution behavior.
2. Run the package-owned host Rexx tests and static contract checks in the target runtime, retaining outputs and environment fingerprints.
3. Qualify one harmless `mvs.system.identity/1` request end-to-end on the real guest, then `mvs.dataset.state/1`, with request/response bytes, host attribution, JES/guest evidence and typed error classifications.
4. Publish capability maturity by operation and provider; do not promote a static fixture pass into a live target claim.
5. Exercise cross-tenant denial separately (FLYLO and OURLADYAIR): shared executable and transport infrastructure never imply shared datasets, spool, principals or operational authority.

## Non-goals and missing work

No new competing registry, RPC dispatcher, wire transport or identity authority. No silent upgrade from available Library head to accepted dependency. No assertion of successful ED209 guest execution in this document. The complete pre21 executable package is not being imported by this documentation-only commit; source admission and guest qualification remain explicit follow-up work.

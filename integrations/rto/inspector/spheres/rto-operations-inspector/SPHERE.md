# RTO Operations / Plan42 / Inspector sphere

**Sphere ID:** `rto-operations-inspector` (candidate, not yet registered with LLM Gopher)

**Distinction:** The existing Gopher sphere `rto` resolves to *RTO distributed secure transport*, not this RTO command-operation tree. It must not be overwritten or silently repurposed.

## Ownership and contract

REX10 integration lane owns RTO Inspector evidence tooling, Plan42 integration adapter, and verification rules; it does not own InspectorClouseau engine or the RTO command/authority implementation. Source status is r141 candidate on top of r140. RTO rule packs live in `configs/inspector/rules`; generic Inspector stays under `plan42/framework/alchemy`.

## Semantic objects

- `RTOCommand` request/dispatch entry; `RTOCommandRegistry` visibility discovery.
- `RTOOperationRegistry` operation lookup.
- `RTOOperationSecurityContext` authorization boundary (Inspector cannot replace it).
- `RTOInspectorRules` binds project roots and source trails to Inspector Clouseau.
- Inspector trace requests and deterministic sidecars remain evidentiary inputs.
- `rto_inspector_import` emits structured, untrusted local-report observations and explicitly labels absence of real live evidence.

## r141 change

Old r140 text search could classify a class as observed merely because a warning mentioned it. r141 permits only expected-schema structured snapshot object classes; a valid receipt reports installed tracing rules, not method execution. Negative proof covers forged prose, failed receipt, identity mismatch, symlinked file, and zero rules. Plan42 module spec and regression checks are updated accordingly.

## Open work and acceptance

1. Obtain actual host ooRexx/Inspector live run on RTO authority corridor with successful deterministic receipt state.
2. Validate source/package path `::requires` dependencies before live installation; fail closed on missing packages.
3. Pin the exact refreshed framework and standalone Inspector candidate revisions; do not substitute newer Library sources on name alone.
4. Link trace-request receipt hash/evidence chain to an authorized host identity when requested by governance.
5. Publish an LLM Gopher sphere revision only through an authorized sphere publication workflow; this Markdown is a candidate source of truth, not proof of sphere-service registration.
6. Publish the complete RTO runtime source under a confirmed GitHub subtree and reconcile against the accepted ZIP base, rather than overwriting `animatedads/alchemy` existing unrelated files.

Validated static boundary does not imply executed dispatch or operational authority.

## r142: configured-request binding and evidence limits (29 October 2026)

Inspector receipts are valid only for an existing, schema-valid **project trace request** in `data/inspector-trace-requests`. A receipt for an unknown request, an absolute or traversal path, or a symlinked/invalid project rule is rejected as a failure. The same namespace check applies to successful trace-load acknowledgement records. These negative cases are verified by `tests/rto_v105r142_inspector_config_binding_static.py`.

The importer reports `configured_trace_sha256` solely as **local configuration fingerprints**. The current receipt schema does not bind a request content digest, signer, inspected host or exact source revision. Therefore `receipt_binding` is `CONFIGURED_FILENAME_ONLY_UNATTESTED_SOURCE_VERSION` and `host_attestation` remains `NOT_VERIFIED`. A local filename match is never a claim that the remote runtime loaded the same bytes or that the observed object was executed.

RTO's authority path is unchanged. This lane does not implement or install the Rasen Falcon website, mail, LDAP, HTTPS or MU↔MI transport. For service activation, these Inspector reports can be supporting observation only, never a substitute for an independent live service test, signed deployment receipt, or permission from RTOOperationSecurityContext.

**GitHub source tracking:** `animatedads/alchemy`, draft PR #32, `integrations/rto/inspector/`. This sphere is a *candidate* distinct from the established `rto` distributed-transport sphere; LLM Gopher registration has not occurred.
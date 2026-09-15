# Response to Grok v0.3 Algorithm Relation Review

This document maps the v0.3 adversarial findings to executable v0.4 changes.

| Grok finding | v0.4 disposition | Evidence |
|---|---|---|
| Caller-supplied `inputOid` / `invocationId` are too trusted | **Fixed** | `canonicalInputHash` is SHA-256 of actual provider-canonical input; caller IDs are excluded from materialization key. Same IDs + changed content reruns provider. |
| Prefer content-addressed materialization | **Implemented** | `materializationId` derives from algorithm/version + source manifest + canonical input + world snapshot. |
| Source fingerprint should be manifest/Merkle-like rather than one file | **Implemented flat canonical manifest for v0.4** | `AlgorithmSourceManifest`; strict mode `FILE_HASHED`; external unbound plugin => `INCOMPLETE`. Merkle structure remains a review question. |
| `DETERMINISTIC_SNAPSHOT` over-claims | **Removed** | Strict declaration is `DETERMINISTIC_GIVEN_MATERIALIZED_INPUT`. Static guard rejects legacy label. |
| Plugin set/approval set/capability defaults must be identity-bearing | **Implemented** | RYTA canonical input includes plugin config, approvals, policy/quorum, approval scope and capability-default policy. Dedicated identity test. |
| Camera model/input state must be frozen | **Tightened for current adapter** | Adapter canonicalizes all exported `CameraCurrentCondition` fields plus sorted metric signals; component source is file-manifest hashed. |
| Structural typing is insufficient | **Implemented v0.4 lexical type/domain checking** | `TEXT/OID/INTEGER/NUMBER/BOOLEAN`, finite domains, explicit NULL vs omission, invalid rows/results never cached. |
| Read planner needs strict pushdown rules | **Implemented conservative read operator** | No provider pushdown API; full materialization precedes output filter/projection/LIMIT. |
| Future side-effect taxonomy should be separate | **Reserved, not enabled** | Read operator accepts only `SIDE_EFFECT_CLASS=NONE`. |
| Audit replay identity needs care | **Strengthened beyond original review** | Explicit `materializationId`, `providerExecutionId`, `invocationId`, `inputOid`, `worldSnapshotOid`; replay preserves provider execution while rebinding audit invocation. |

v0.4 is therefore intended to be reviewed as an identity/typing/planner-boundary candidate, not as a request to reopen the HardWorld v0.2 rule-language semantics.

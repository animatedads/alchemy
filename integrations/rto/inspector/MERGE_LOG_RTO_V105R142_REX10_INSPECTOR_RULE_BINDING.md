# REX10 RTO v105r142 merge log — Inspector configured-rule binding

Baseline: `rto_v105r141_rex10_inspector_evidence_truth_full.zip`. No full-file overlay from a remote branch. The `rto-inspector` Rasen Falcon lane was created and CLAUDE notified via REQ-00001825.

Modified: `tools/rto_inspector_import.py`, `specs/plan42/rto_inspector_live_import.spec.json`, `spheres/rto-operations-inspector/{SPHERE.md,sphere.json}`.
Added: `tests/rto_v105r142_inspector_config_binding_static.py`, `docs/plan42/INSPECTOR_CONFIG_BINDING_R142.md`.

Admission now requires a configured project rule; absolute/traversal/symlinked/unknown identities fail closed. Project rule hashes are local audit references only, not attested runtime proof. This is deliberately bounded to Inspector evidence import and does not change `RTOOperationSecurityContext` or services.

NOT CLAIMED: real ooRexx live Inspector run, remote signed evidence, source revision equivalence, production service deployment, or Gopher registration.
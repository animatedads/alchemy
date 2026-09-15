# Handover — regulated_intermediary_distribution_v0.8-dev4

This is an early UI development candidate continuing the v0.8 UI line. It does not replace sealed v0.7 as the accepted authority/release baseline.

The principal change is operator presentation: stronger hierarchy, denser worklist/table treatment, compact horizontal journey stages, grouped case facts, and a separate next-action zone. No browser-side business authority was added.

Run `./start.sh` for the immediate static preview. Run `./start.sh --live` when the ooRexx/Wire UI dependency environment is configured. Both modes use the package Node launcher; do not substitute Python.

Validation performed for this cut:
- Node syntax checks: PASS
- journey presentation model: PASS
- package-root Node start smoke test: PASS
- actual Alchemy browser -> WebSocket -> Queue Fabric -> RID Wire UI -> signing -> browser projection: PASS
- browser fixture executed with ooRexx 5.3.0 r13196 extracted from the supplied package and the UI-relevant dependencies in `oorexxapis(20260901-112043).zip`.

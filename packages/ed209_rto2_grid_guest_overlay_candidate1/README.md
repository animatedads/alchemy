# ED209 RTO2 guest work overlay candidate

This is the **missing guest execution source** accompanying the ED209 controller-response and fleet-controller submissions. It is deliberately a narrow additive overlay: it does not replace a deployed Grid handler, nor introduce a new Queue Fabric transport.

- `rexx/rto2_work_dispatch.rex.inc` is the manifest-authorised RTO2 work branch inserted into a previously qualified Grid handler.
- `rexx/rto2-smoke-local.rex` is an isolated count/commit/capture validation worker.
- `ops/stage_grid_overlay.py` injects the branch and RTO2 classes without discarding existing F/H FAST, register, heartbeat or queue-envelope fixes. It refuses divergent handlers.
- Tests prove original handler preservation, RTO2 injection and fail-closed mismatches.

Provenance: originally built and locally qualified in `ed209_rto2_20mi_candidate2_managed.zip` SHA-256 `940ee1835f9dd53ceea42a14e0eb7880e4dc374d6813cfbc686972debe23b4e1`. This extraction uses a standalone fragment instead of an entire replacement handler to avoid undoing known live fixes.

This is source for Autobuild qualification only. It does not contain private commissioning authority, is not a complete standalone Grid distribution, has not been applied to F/H, and does not prove 20 live RTO2 executions or dev25 native named-service FIRST admission.

Operator: reconcile with the **actually installed** F/H handler, build an isolated MI, verify the real cpio with the controller's preflight, test FAST, register/heartbeat, then RTO2 result. Preserve rollback.

# ED209 RTO2 20-MI owning-MU controller and fleet sorter (candidate)

This submits the previously missing **controller-side** source to GitHub as ordinary files, alongside the independently submitted symbolic-route/guest-grant fix and the ED209 Gopher sphere.

Provenance: selected source contracts and test approach from `ed209_rto2_20mi_candidate2_managed.zip`, SHA-256 `940ee1835f9dd53ceea42a14e0eb7880e4dc374d6813cfbc686972debe23b4e1`. The complete staged source contains additional native ooRexx guest handlers and image overlays **not included in this specific controller slice**; its local code is still a candidate until integrated and live-qualified.

- `bin/run_20mi.py` calls **owning MUs** through the approved operator `sshnode.sh`; no SSH commands execute within guests.
- `bin/controller_commit.py` validates RTO2 captured state and atomically persists immutable controller receipts.
- `bin/run_all_20.sh` invokes one result per assigned MI, outputs deterministic route/value sorts.
- `tests/test_controller.py` checks 20 unique routes, digest/authority fail-closed, idempotence, and missing MI.

Run: `python3 -m unittest discover -s tests -v`

A live PASS requires twenty **real** distinct MI jobs with authenticated XTP returned results and committed RTO2 state. This package does not declare 20/20 accepted, nor does it implement named-service FIRST/KEY/DATA in Grid, mirrored RTO2, or production placement leases. H-local test keys do not imply production federation.

Security: no private commissioning keys; no direct Git write to main. Store source through Autobuild only. Tracking https://github.com/animatedads/alchemy/issues/17.

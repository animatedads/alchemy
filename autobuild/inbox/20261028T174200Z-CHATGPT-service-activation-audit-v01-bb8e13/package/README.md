# ALCH-SWEEP-B — service activation audit v0.1

Consumer/installation-side read-only audit for Project Alchemy, independent of the source/provider inventory in Sweep A. Exact Git evidence, blockers and five shortest gated paths are in `docs/SERVICE_ACTIVATION_DAG.md` and `docs/SERVICE_CRITICAL_PATH.csv` (54 dependency edges).

The executable `tools/check_activation.py` is an **offline source contract checker**, not a service installer, DNS scanner, network probe or source acceptance authority. It can identify a missing release-role payload, wrong private HTTPS unit names, a missing BashQueues ticker `.timer` install destination, and absent exact Queue Fabric Autobuild source directories. Optionally checks a full candidate Website Builder ZIP extraction against its SHA-256 source lock. It does not know whether hosts are running and never claims live PASS.

```sh
# Package-only audit validation and 8 disposable-fixture tests
python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 tools/check_activation.py --audit-only --json

# Existing full Git checkout (read-only; no shell commands or network)
python3 tools/check_activation.py --repo /path/to/alchemy --json

# Fail a release audit gate (rc 3) when blockers remain
python3 tools/check_activation.py --repo /path/to/alchemy --strict --json

# Optional candidate publication hash check, needs exact unpacked submission package
python3 tools/check_activation.py --website-candidate-dir /path/to/candidate/package --json
```

`--strict` returns rc 3 for source blockers and unresolved acceptance; rc 2 for malformed audit evidence. `--audit-only` returning success means **CSV structure is valid, not services commissioned**. The proof has no live host, key, certificate, DNS, WLU quota or GitHub acceptance assertions.

## Scope / ownership

The authenticated Rasen Falcon lane `service-activation-audit` owns only this audit/report/checker. Website, Publisher, HTTPS, LDAP, mail, general Deployment, ED209/RTO2, XTP and GPU source stay with their respective lanes. The only writes created in Git are immutable Autobuild submission source and ready marker; changes to production hosts are out of scope. This archive does not include secrets or imported runtime/provider source.

Source/release protocol: `GIT_SUBMISSION.md`. Never merge the `autobuild-submit/*` branch directly into main; the receiver has independent test and publication gates.

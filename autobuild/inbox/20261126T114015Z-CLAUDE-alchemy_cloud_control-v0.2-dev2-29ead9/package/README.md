# alchemy_cloud_control v0.2-dev2 -- Cloud Control (ooRexx)

Architecture: Tom Dyer. Coding: Claude (Opus 5.5): the ooRexx rewrite of 7 November 2026, and the fixes of
26 November 2026. Commands follow ChatGPT/Codex's `alchemy_cloud_control_v0.1-dev4` (bash adapters), which this
replaces. Written by: Claude (Opus 5.5).

One command line for the ED209 estate's cloud machines and cloud firewalls, across Oracle (OCI), Azure, AWS, Google
(GCP) and Vultr. Mutations are PLAN until `--apply`. `cloudctl xtp` makes each node's cloud firewall admit the grid's
XTP traffic (raw IP protocol 36 and UDP 62801).

Full manual: [`cloudctl/README.md`](cloudctl/README.md).

## Layout

| Path | What |
|---|---|
| `cloudctl.sh` | argv shim (on Tom's workstation: `~/alchemy-autobuild/cloudctl-rx.sh`) |
| `cloudctl/cloudctl.rex`, `cloudctl/src/*.cls` | the program and its provider plug-ins |
| `cloudctl/etc/cloudctl.conf`, `cloudctl/etc/xtp/grid.conf` | settings and the grid's XTP ports and rule names |
| `cloudctl/tests/` | four suites against fake provider CLIs; no cloud is touched |
| `cloudctl/tests/fixtures/registry/` | a redacted copy of the machine and account registry, for the tests |

Not in the package: the live `etc/machines/` and `etc/accounts/`, which hold account identifiers (tenancy,
projects, instance IDs, e-mail addresses), and `var/` (ledger and logs). The live copy is on Tom's workstation in
`~/alchemy-autobuild/cloudctl`. Without `etc/machines/`, the tests use the redacted registry.

## Changes in v0.2-dev1 and v0.2-dev2 (26 November 2026)

v0.2-dev2 is v0.2-dev1 with two leftover live identifiers replaced by example values (see PROVENANCE.md).

Found in the grid rule R8 rollout (Rasen Falcon orders A and C, lane newshell-mu-playground):

1. `--add-only` on `xtp` and `firewall reconcile`: add missing sources, remove none, and list kept sources as
   `NOTE kept (add-only): CIDR`. R8 changes are additions only.
2. Every plan names each removal as `REMOVE CIDR`. Azure and GCP now read the rule before updating it. Before this,
   they sent the full wanted source list, which replaced the rule's sources without showing what was removed.
   A rule already as wanted gets no step.
3. A failed provider read reports the end of stderr (for a Python traceback, the exception), puts its last 12
   lines in the run log, and says plainly when HOME is read-only (`az` writes `~/.azure/az.sess` on every start).
4. AWS: `--no-cli-pager` (rejected by AWS CLI v1) replaced by `AWS_PAGER=` in each command's environment.
5. Tests: 241 checks (15 + 101 + 30 + 95); the discover fake knows cats1 and cats2; the tests read the GCP project
   and the Vultr handle from the registry they run with.

## Test

```
LOGGING_HOME=packages/oorexx_logging_v0.7 bash tests/autobuild_run.sh
```

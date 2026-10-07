# Validation — v0.1-dev2

Executed in the build container:

* `tests/test-helper.sh` — PASS.
* `bash -n libexec/firewall-nft` — PASS.
* `oorexx_standards_enforcer.py --strict --json <archive>` — PASS, 0 errors, 0 warnings.
* exact archive inventory generated and hashed.

Not claimed in this container:

* ooRexx translation/execution: `rexx` / `rexxc` are not installed here.
* live nftables mutation: `nft` is not installed here.
* live QueueRexx `queue.transport/2` A/B qualification: the runtime packages are
  not mounted in this build container.

The package contains `tests/test_firewall_control.rex` and explicit QueueRexx
server/client qualification programs for those gates on an ooRexx/QueueRexx
host.

# Source and authority references

- Attached `Computer` (2026-10-13): three-line ooRexx starter. Replaced in new package, original left untouched.
- Library `oorexx_intention_service_v0.1-dev11.zip`: native ooRexx IntentionService source, copied into `vendor/` without editing upstream files; dynamic snapshots, discovery generations, plan, READY-gated dispatch.
- Library `oorexx_management_intention_discovery_v0.1-dev8.zip`: inspected to confirm fresh, domain-owned transient discovery. No claim that its generic relationship resolver is wired into this release.
- Library `oorexx_network_transport_intentions_v0.1-dev3.zip`: inspected only; not used as a firewall control layer.
- Attached `sshnode(1).sh`: copied unchanged to `adapters/sshnode.sh`. This is the authoritative SSH implementation *as attached*, not an implementation of SSH in Computer. Real host's latest version should be bound using `COMPUTER_SSHNODE`.
- Attached `cloudctl(2).sh`: copied unchanged to `adapters/cloudctl.sh`. Scoped cloud operations available, but no generic verified ed209f action metadata.
- Attached ooRexx Debian package `oorexx-5.3.0-13196.ubuntu1604debug.x86_64(20261010-152438).deb`: extracted under the test sandbox without system installation; interpreter reported ooRexx 5.3.0 r13196.

No SSH keys, cloud credentials, shell dotfiles or user service files are bundled or written by Computer. All tests use local fixtures and the SSH dry-run guard.

- Claude Sonnet 5.5 first cut: supplied `Computer(1)`, `Computer.rex`, `ComputerIntentions.cls`, and `ComputerTest.sh`, retained as inert reference under `docs/claude_reference`; 39/39 original tests passed in isolated ooRexx runtime, but the implementation was selectively merged after safety review.

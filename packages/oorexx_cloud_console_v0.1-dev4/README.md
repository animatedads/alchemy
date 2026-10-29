# ooRexx Cloud Console v0.1-dev4

One provider-neutral ooRexx surface for Azure, Vultr, GCP, AWS and OCI, usable by humans, shell/code automation, Codex-style agents and ooRexx callers.

## Common vocabulary

```text
providers
doctor
workspace

machine list|create|start|stop|reboot|destroy
firewall list|allow|revoke
firewall reconcile
```

`firewall reconcile` is available only through the `alchemy.cloud-control/0.1` backend and replaces the non-empty source set for one scoped ingress protocol/port rule. It remains PLAN-only until `--apply`.

## Authority seam

Set `ALCHEMY_CLOUD_CONTROL=/path/to/cloudctl.sh` or use `--backend cloud-control --cloud_control PATH`. `--backend auto` selects Cloud Control when configured. Provider-native mutation remains an explicit development/test fallback.

Reads remain provider-native observations and are labelled separately from the selected mutation backend. Provider handles are not allocator node IDs. Credentials and IAM remain provider authority.

## Safety

- mutations default to `PLANNED`;
- `--apply` is required to execute;
- destroy additionally requires exact `--confirm MACHINE`;
- interactive apply requires typing `APPLY`;
- secret-bearing options/spec fields are rejected;
- `--workspace` changes execution cwd, never authority;
- `bin/cloudctl` preserves shell argv losslessly for Codex paths and option values.

JSON responses use `oorexx.cloud.console.result/1`.

## Qualification

Qualified on 2026-10-29 under exact ooRexx 5.3.0 r13196, including source/standalone compilation, full regression suite, nested JSON escaping/round-trip, Cloud Control backend PLAN/APPLY, and a real console -> Cloud Control -> provider-fixture reconciliation path. No live provider mutation is claimed.

# Architecture — ooRexx Cloud Console v0.1-dev2

## Control flow

```text
Human console / shell / Codex / ooRexx caller
                    |
                    v
              CloudApp
       stable command vocabulary
                    |
          plan/apply authority
                    |
                    v
              Provider adapter
      Azure | GCP | AWS | OCI | Vultr
                    |
                    v
            installed provider CLI
                    |
                    v
              provider cloud API
```

## What Cloud Console owns

Cloud Console owns:

- common cloud-control vocabulary;
- provider resource inventory normalization;
- provider command construction;
- plan-before-apply mutation fencing;
- exact confirmation for machine destruction;
- safe provider-CLI working-directory selection;
- human table / interactive rendering;
- stable JSON result envelope.

## What it does not own

### Cloud identity and credentials

Provider CLI configuration and provider IAM remain authoritative. Cloud Console deliberately rejects secret-bearing command/spec fields.

### Managed node identity

A provider resource handle is an action locator, not a stable allocator node ID. Managed Node Host Profile owns provider-neutral host evidence; Job-to-Node Allocator owns hard eligibility/ranking/placement leases.

### Job execution

Creating or rebooting a VM is not the same as dispatching jobs to it. Queue Fabric / WLU / allocation layers retain their existing execution and admission responsibilities.

### API egress authority

The current v0.1 adapter uses provider CLIs. A future native HTTPS adapter may consume API Client where appropriate, but must not silently absorb provider signing/authentication or API Client egress-session authority.

### Workspace/storage authority

`--workspace` selects the current directory in which the provider CLI runs. It does not:

- establish durable object identity;
- create allocator identity;
- grant IAM rights;
- grant mutation rights;
- make temporary workspace bytes durable state.

This follows the current Workspace GPT, Storage Fabric, Placement Layers and Semantic Source Control Gopher doctrine: path/location/context and semantic/authority identity are separate concerns.

## Codex argv transport

A raw ooRexx program receives one flattened command tail and cannot reconstruct the original shell argv perfectly. `bin/cloudctl` therefore writes the already-tokenized shell arguments to a mode-0600-style temporary file (under `umask 077`), passes only its path through `OOREXX_CLOUDCTL_ARGFILE`, and deletes the file after ooRexx returns.

The ooRexx core parses that token array directly. As a result:

- `--workspace "/path with spaces"` is exact;
- apostrophes are exact;
- descriptions/labels with spaces remain one value;
- option boundaries are not inferred from whitespace after the shell has already parsed them.

Direct ooRexx callers use `CloudApp~runTokens(.Array)` and bypass this transport entirely.

`OOREXX_CLOUDCTL_WORKSPACE` remains a supported direct automation override when only workspace context needs to change.

## Mutation model

Every create/lifecycle/firewall mutation first produces a provider command and returns:

```text
status = PLANNED
```

No provider command executes unless `--apply` is present.

Machine destruction adds a second static condition:

```text
--confirm must exactly equal --machine
```

Interactive execution adds a third human check: the operator must type `APPLY` after the exact provider command is displayed.

Provider IAM is still the final authority when the command actually reaches the provider.

## Normalized machine record

```text
provider
handle       provider action locator
name         display name
region       region/zone/availability domain where available
state
public_ip
private_ip
```

No `nodeId` is synthesized.

## Normalized firewall record

```text
provider
rule
scope
direction
protocol
ports
source
description
```

Protocol names are normalized where practical (`6` -> `tcp`, `17` -> `udp`, `1` -> `icmp`). Provider-native rule identity remains visible for revocation.

## Provider-specific semantic choices

- Azure `stop` -> `az vm deallocate`, because ordinary `az vm stop` remains billable for compute allocation.
- GCP `reboot` -> native `gcloud compute instances reset`; this is explicitly documented as a hard reset and the exact command is visible in PLAN.
- OCI uses graceful `SOFTSTOP` and `SOFTRESET` for common stop/reboot.
- AWS and Vultr use their native lifecycle operations.

## Error posture

- unknown provider: fail closed;
- malformed/missing required context: fail closed;
- provider non-zero rc: ERROR with provider stderr/stdout evidence;
- invalid provider JSON on inventory: ERROR rather than guessed state;
- inaccessible workspace: fail before provider execution;
- secret-bearing spec/option name: reject;
- malformed provider record shapes: adapters use staged type checks rather than short-circuit assumptions.

The last point is important in ooRexx because `&` and `|` always evaluate both operands.

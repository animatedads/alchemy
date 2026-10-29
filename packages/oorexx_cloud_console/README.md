
## dev3 — Alchemy Cloud Control mutation backend

The console now has an executable authority seam rather than only a documented one. Mutations may be delegated to `alchemy.cloud-control/0.1 RESOURCE` by setting:

```sh
export ALCHEMY_CLOUD_CONTROL=/path/to/alchemy_cloud_control/adapters/cloudctl.sh
```

Or select it explicitly with `--backend cloud-control --cloud_control PATH`. With the path configured, `--backend auto` selects Cloud Control for machine/firewall mutation. `--backend provider-cli` remains an explicit development/test fallback.

Read-side inventory is intentionally independent: it continues through provider-native read commands and is labelled `read_backend=provider-cli`, while the result records the selected `mutation_backend`. This preserves the distinction between observation evidence and mutation authority.

The Cloud Control command receives only normalized operation/context fields, never provider credentials. PLAN/APPLY and exact destroy confirmation remain in this console before delegation. `--workspace` remains only the working directory for the selected transport; it is not authority.

**Qualification status:** dev2 remains the last r13196-qualified console. This dev3 source is a continuation candidate until its ooRexx suite is rerun under 5.3.0 r13196. The included tests extend the dev2 suite with Cloud Control backend cases.

# ooRexx Cloud Console v0.1-dev3 candidate

One provider-neutral ooRexx control surface for:

- Microsoft Azure (`az`)
- Vultr (`vultr-cli`)
- Google Cloud (`gcloud`)
- Amazon Web Services (`aws`)
- Oracle Cloud Infrastructure (`oci`)

The same core is usable by a human, shell/program automation, Codex-style agents, or directly from ooRexx code.

## Design in one sentence

`cloudctl` owns a stable cloud-control vocabulary; provider adapters translate that vocabulary to the installed provider CLIs, while credentials, allocator node identity, execution placement, and workspace storage remain separate authorities.

## Current common vocabulary

```text
providers
doctor
workspace

machine list
machine create
machine start
machine stop
machine reboot
machine destroy

firewall list
firewall allow
firewall revoke
```

`instance` is an alias for `machine`. Provider aliases include `az`, `gcloud`, `google`, `amazon`, `aws`, `oracle`, and `oci`.

## Quick start

The recommended entry point is the launcher because it preserves real shell argv exactly before handing it to ooRexx:

```sh
./bin/cloudctl providers
./bin/cloudctl doctor

./bin/cloudctl machine list --provider azure
./bin/cloudctl machine list --provider amazon --region eu-west-2
./bin/cloudctl machine list --provider gcloud --project my-project
./bin/cloudctl machine list --provider oci --compartment ocid1.compartment... --region uk-london-1
./bin/cloudctl machine list --provider vultr
```

For automation:

```sh
./bin/cloudctl machine list --provider aws --region eu-west-2 --json
```

Every JSON response uses schema:

```text
oorexx.cloud.console.result/1
```

## Mutations are plan-first

A mutation is **not executed** unless `--apply` is present.

```sh
./bin/cloudctl machine reboot \
  --provider aws \
  --machine i-0123456789abcdef0 \
  --region eu-west-2 \
  --json
```

returns a `PLANNED` result containing the exact provider command.

Only after review:

```sh
./bin/cloudctl machine reboot \
  --provider aws \
  --machine i-0123456789abcdef0 \
  --region eu-west-2 \
  --apply \
  --json
```

Destroy is deliberately stricter. The exact machine handle must be repeated:

```sh
./bin/cloudctl machine destroy \
  --provider aws \
  --machine i-0123456789abcdef0 \
  --region eu-west-2 \
  --apply \
  --confirm i-0123456789abcdef0
```

Interactive mode asks for `APPLY` again before an applied mutation.

## Codex / workspace contract

The provider CLI working directory is explicit context:

```sh
./bin/cloudctl \
  --workspace "/worktrees/Codex Bob's cloud change" \
  machine list --provider aws --region eu-west-2 --json
```

The launcher transports argv losslessly, including spaces and apostrophes.

Automation may also set:

```sh
export OOREXX_CLOUDCTL_WORKSPACE=/some/worktree
```

Important boundary: **workspace is not authority**. Changing the working directory does not move credentials, grant cloud mutation rights, redefine a node, or make workspace files durable controller state.

The controller does not currently keep authoritative mutable cloud state in the workspace. It asks each provider for current inventory and uses provider resource handles for cloud actions.

## Direct ooRexx API

Put `src` on `REXX_PATH`, then load `CloudConsole.cls` and pass an `.Array` of tokens. This avoids shell/command-tail reconstruction entirely.

```rexx
app = .CloudApp~new
tokens = .Array~of("machine", "list", "--provider", "aws", "--region", "eu-west-2", "--json")
rc = app~runTokens(tokens)
::requires "CloudConsole.cls"
```

The public command API intentionally returns the same rendered JSON/human result semantics as the shell surface.

## Human console

With no command, run the standalone Rexx program directly or invoke the launcher with no arguments:

```sh
./bin/cloudctl
```

Then:

```text
use azure
machine list
machine reboot --machine /subscriptions/.../virtualMachines/demo
machine reboot --machine /subscriptions/.../virtualMachines/demo --apply
firewall list --scope resource-group:nsg-name
workspace /another/worktree
```

`help` shows the interactive vocabulary.

## Machine create specs

Create accepts a provider-neutral-ish properties file. Command-line options override spec values.

```sh
./bin/cloudctl machine create \
  --provider gcp \
  --spec examples/specs/gcp-small.properties
```

Review the plan, then add `--apply`.

Example specs exist for all five providers under `examples/specs/`.

Secret-bearing field names such as `password`, `secret`, `api_key`, `apikey`, or `token` are rejected in both specs and command options. Authentication remains the provider CLI's responsibility.

## Firewall model

v0.1-dev2 manages rules inside an existing provider firewall scope:

| Provider | `--scope` means |
|---|---|
| Azure | `RESOURCE_GROUP:NSG_NAME` |
| GCP | VPC network name |
| AWS | security-group ID |
| OCI | NSG OCID |
| Vultr | firewall-group ID |

Example:

```sh
./bin/cloudctl firewall allow \
  --provider vultr \
  --scope FIREWALL_GROUP_ID \
  --rule ssh-office \
  --protocol tcp \
  --port 22 \
  --source 203.0.113.0/24
```

Again: that only plans. Add `--apply` to execute.

`firewall revoke` uses the provider's native rule identity: name for Azure/GCP; security-group-rule ID for AWS; security-rule ID for OCI; firewall rule number/ID for Vultr.

## Provider lifecycle semantics

The common verbs deliberately map to the nearest native provider operation:

| Common verb | Azure | GCP | AWS | OCI | Vultr |
|---|---|---|---|---|---|
| start | `vm start` | `instances start` | `start-instances` | `START` | `instance start` |
| stop | `vm deallocate` | `instances stop` | `stop-instances` | `SOFTSTOP` | `instance stop` |
| reboot | `vm restart` | `instances reset` | `reboot-instances` | `SOFTRESET` | `instance restart` |
| destroy | `vm delete` | `instances delete` | `terminate-instances` | `instance terminate` | `instance delete` |

Azure `stop` intentionally uses **deallocate**, not merely power-off, so compute allocation/charging semantics match the normal intention of “tear down idle compute”. GCP's native `reset` is a hard reset; the plan makes that exact command visible before apply.

## Identity boundary

Cloud inventory exposes a provider action `handle` and a display `name`. The handle is **not** an allocator `nodeId`.

For GCP, the displayed action handle is `zone/name` so it is copyable back into `machine start|stop|reboot|destroy` without an additional `--zone`.

Stable managed-node identity belongs to Managed Node Host Profile / Job-to-Node allocation, not to this cloud-control adapter.

## Authentication

`cloudctl` does not ingest cloud passwords, API keys or access tokens. It invokes the already-configured official/provider CLI in the selected workspace and therefore inherits that CLI's authenticated identity and IAM permissions.

Credentials are capability prerequisites, not cloudctl mutation authority: mutation still requires cloudctl's plan/apply gate, and provider IAM remains authoritative at execution.

## Provider context options

Common provider-specific context currently includes:

```text
Azure: --subscription ID, --group RG
GCP:   --project ID, --configuration NAME, --zone ZONE
AWS:   --region REGION, --aws_profile NAME
OCI:   --compartment OCID, --region REGION, --oci_profile NAME, --oci_auth TYPE
Vultr: --vultr_config PATH
```

## Qualification

`tests/run.sh` uses fake `az`, `gcloud`, `aws`, `oci`, and `vultr-cli` executables. It does **not** require cloud credentials and cannot intentionally mutate a live account.

The suite covers:

- JSON parser/encoder
- all five normalized machine inventories
- all five normalized firewall inventories
- lifecycle plan/apply fencing
- exact destroy confirmation
- firewall planning
- create specs for all five providers
- secret-bearing field rejection
- GCP copyable zone/name handles
- OCI protocol normalization
- standalone execution from an unrelated current directory
- direct ooRexx `.Array` API
- Codex workspace paths containing spaces and apostrophes
- lossless launcher arguments containing spaces and apostrophes

See `qualification/QUALIFICATION.txt`.

## Current limits

- The provider CLIs must already be installed and authenticated for live use.
- v0.1-dev2 manages firewall **rules**, not creation/deletion of the provider-specific firewall container itself.
- OCI machine inventory does not perform an extra VNIC/IP lookup yet; its IP columns are intentionally blank rather than guessed.
- GCP `reboot` maps to the native Compute Engine reset operation, which is a hard reset.
- The package does not invent durable managed-node identity from a cloud provider resource ID.
- Live provider qualification was deliberately not performed in this build; all mutation qualification is fixture/fake-CLI based.

## Layout

```text
bin/cloudctl                 recommended shell/Codex entry point
cloudctl.rex                 standalone ooRexx program
src/CloudConsole.cls         reusable ooRexx classes
examples/specs/              provider create examples
tests/                       offline provider regression suite
docs/ARCHITECTURE.md         authority and integration boundaries
qualification/               exact qualification evidence
```

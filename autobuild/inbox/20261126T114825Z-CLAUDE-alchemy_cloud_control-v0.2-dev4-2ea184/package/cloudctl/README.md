# Cloud Control (ooRexx)

Architecture: Tom Dyer. Coding: Claude (Opus 5.5), 7 November 2026. Written by: Claude (Opus 5.5).

Replaces the bash `cloudctl.sh` on the workstation and the dev4 `adapters/cloudctl.sh` (Codex). One command line, one rule set, one ledger; each cloud provider is a plug-in.

```
cloudctl PROVIDER machine list|create|start|stop|reboot|destroy [--option value ...] [--apply] [--confirm M]
cloudctl PROVIDER firewall list|allow|revoke|reconcile [--option value ...] [--add-only] [--apply]
cloudctl PROVIDER restart HANDLE|MACHINE        the old form; same as machine reboot
cloudctl providers | accounts | machines
cloudctl ops [--since YYYY-MM-DD]                operations ledger
cloudctl hours                                   running hours per machine
cloudctl check PROVIDER NOUN VERB [...]          rules only: print the buckets, run nothing
cloudctl discover [NODE|all] [--write]           find each machine's instance and firewall from its address
```

## Discovery (`cloudctl discover`)

The machine file's `address=` is the key. Each plug-in makes only read calls:

| Provider | Path | Fills |
|---|---|---|
| AWS | instance by public IP in `region=` | `handle`, `scope` (its security group) |
| Azure | public IP → NIC → VM; NSG on the NIC, else on the subnet | `handle`, `scope` as `RG:NSG` |
| GCP | the project's instances, matched on external NAT IP | `handle`, `zone`, `scope` (network) |
| OCI | the compartment's instances → VNIC with the IP → its NSG, else its subnet's security list | `handle`, `scope` |
| Vultr | instances, matched on main IP | `handle`, `scope` (firewall group, or `none`) |

Each value is shown with one of three results:

- `same`: the machine file already says this.
- `fill`: the file is blank; `--write` fills it.
- `DIFFERS`: never overwritten; both values are shown.

`--write` keeps every comment and copies the old file to `var/machines-backup/` first. Every node's discovery is a ledger row (`machine discover`, READ or WRITE).

`scope=none` means no cloud firewall sits in front of the machine. `cloudctl xtp` skips such a node, and its host firewall carries XTP.

Before any call, the `kit` rule checks that the provider's command-line tool is installed. A missing tool is a STOP that names it, for discovery and for every other operation.

### Vultr: REST

Tom's decision, 7 November 2026: the Vultr plug-in uses the Vultr API v2 over REST, as the workstation `cloudctl.sh` did, not `vultr-cli`.

Every call runs `bin/vultr-api.rex METHOD PATH [BODY]`. The helper finds the key in this order:

1. `vultr_api_key_file=` in `cloudctl.conf`
2. the `VULTR_API_KEY_FILE` environment variable
3. the `VULTR_API_KEY` environment variable
4. `~/.config/vultr/api-key`

A key file must be mode 600 or 400. The helper gives the key to curl on stdin (`-H @-`), so it never appears in argv, `ps`, the operations ledger or the events log. A request body travels base64-encoded and reaches curl in a mode-600 temporary file, which is deleted after the call. The plan shows the body as JSON beside the command.

The `kit` rule checks for curl, and the `vultrkey` rule checks for a usable key before any call.

## How a call runs

1. **Rules.** Core rules, then the plug-in's required fields and its own rules. Findings land in STOP, WARN and INFO buckets. Any STOP refuses the call (exit 2) and is still written to the ledger.
2. **Observe.** Read-only. Only `firewall reconcile` uses it, to fetch the current rules.
3. **Plan.** The plug-in returns the provider commands. Each one is marked READ or CHANGE.
4. **Apply.** Only with `--apply`. Without it, a mutation prints its CHANGE steps and `PLANNED`, and nothing reaches the provider.
5. **Record.** Every call is written to `var/ops-YYYYMM.tsv`. Successful machine changes are also written to `var/machines.tsv`. Events go through `oorexx_logging` to `var/events-YYYYMMDD.log`.

`destroy` also needs `--confirm` with the exact machine name.

Secret-bearing options (`--token`, `--password`, `--api-key` and similar) are refused. Credentials stay in each CLI's own config, and gcloud always runs through `gcloud-account.sh` with an explicit account.

## Configuration (`etc/`)

| File | Holds |
|---|---|
| `cloudctl.conf` | plug-in registrations, gcloud wrapper, log and work directories, logging package |
| `accounts/NAME.account` | `provider=`, the provider's account selector, defaults (project, region…) |
| `machines/NAME.machine` | `provider=`, `account=`, `handle=`, zone/region, project, firewall scope |

`--machine ed209e` reads `machines/ed209e.machine`, and its fields fill any option not given on the command line. For example, `gcp machine reboot --machine ed209e` resets `instance-20260906-161857` in `us-central1-a` under project `PROJECT (the machine file's project=)` through account `animated-ads-cy`.

## Adding a provider

A new provider needs one new file and one new line in `cloudctl.conf`:

```
provider.hetzner=$CLOUDCTL/src/CloudHetzner.cls:CloudHetznerProvider
```

The class subclasses `CloudProviderPlugin` and provides `operations`, `optionNames`, `required(noun, verb)`, `rules`, `plan(q, config, evidence)` and, if it reconciles, `observe(q, config, exec)`. It does not need to handle parsing, rules, PLAN/APPLY, the ledger or logging.

## GCP Spot

`gcp machine create` accepts:

- `--provisioning-model SPOT`
- `--max-run-duration 80m` or `--termination-time`
- `--instance-termination-action STOP|DELETE`
- `--preemption-notice-duration 0s|120s`
- boot disk size and type, metadata

The rules refuse:

- a run limit without a termination action
- a notice other than 0s or 120s
- a create with no image

## Differences from dev4

- PLAN is the default; mutations need `--apply`.
- Each machine list prints valid JSON on stdout with nothing else, so it can be piped.
- GCP reconcile with protocol `all` sends `--rules all`, gcloud's own spelling; dev4 sent `*`.
- AWS `firewall allow` no longer sends the description as `--tag-specifications`; the API rejects it there.
- OCI rule JSON is built with `json.cls`, so the source address is escaped.
- Vultr goes through the REST API, as the workstation script did, but the key is passed to curl on stdin, not in a `-H` argument.

## XTP ingress (`cloudctl xtp`)

```
cloudctl xtp show [NODE|all] [--workstation CIDR]       the desired ingress, no provider call
cloudctl xtp NODE|all [--workstation CIDR] [--add-only] [--apply]    reconcile each node's cloud firewall to it
```

This replaces the live script's `allow-xtp-peers`, `replace-xtp-peers`, `allow-workstation-xtp` and Azure `set-sources`. Those took source lists typed by hand and behaved differently per provider: AWS only ever added, Azure kept only the last workstation source, and OCI duplicated its UDP test-range rules on every run. Here the grid itself is the input:

- `etc/machines/NODE.machine`: `xtp_link=L3|L4`, `address=`, `provider=`, `scope=` (the node's cloud firewall), plus `region=`, `account=` and `target-tags=` where the provider needs them.
- `etc/xtp/grid.conf`: `udp_port` (62801), `workstation` (CIDR), `workstation_udp` (62000-63000), and the rule names.

L3 is native XTP (IP protocol 36) between MUs. Google nodes are L4: XTP over UDP on the commissioned port. For node N:

| Slot | Rule (GCP, Azure) | Sources | When |
|---|---|---|---|
| peers-raw | `ed209-xtp-peers` | every other L3 node | N is L3 |
| peers-udp | `ed209-xtp-udp` | every L4 node; every peer if N is L4 | always |
| ws-raw | `ed209-xtp-workstation-raw36` | the operator workstation | N is L3 |
| ws-udp | `ed209-xtp-workstation-udp` | the operator workstation, UDP range | workstation set |

Each slot becomes one ordinary `firewall reconcile`, so the same rules, PLAN/`--apply`, ledger and log apply, under one job id per run.

How the providers differ:

- **AWS, OCI and Vultr** keep CIDR sets keyed by protocol and port, so slots with the same protocol and port are merged first. Otherwise one slot's reconcile would remove the other's sources.
- **Azure** cannot select protocol 36, so raw slots become a source-scoped any-protocol rule, as before, at priorities 250/249/248/247.
- **Vultr** cannot select protocol 36 at all: raw slots are dropped with a WARN and must be carried by the host firewall.
- **ed209f** (Clouvider) has no cloud plug-in. `show` lists its slots for the host firewall.
- **OCI** scopes can be an NSG or a security list. A security list is read, changed and written back in one update per slot, with the CLI's kebab-case rules rewritten in the camelCase the update expects; the bash script mixed the two.

Before a node can be reconciled, its machine file must be complete. `cloudctl xtp NODE` names exactly what is missing (STOP `xtpscope`, `xtpregion`, `xtpaccount`).

Still to do:

- Host firewalls (firewalld on A and B, UFW on H and K) are an ensure step, not Cloud Control.
- Legacy UDP 43601-43656 test-range entries are left as they are; `firewall list` shows them.
- A slot with no sources leaves its rule alone rather than emptying it.

### Add-only, named removals, error reasons (26 November 2026)

Changed by Claude (Opus 5.5); architecture Tom Dyer. Found in the R8 rollout (orders A and C).

- **`--add-only`** (on `xtp` and on `firewall reconcile`): add the missing sources and remove none. Every source a full reconcile would remove stays, and is listed as `NOTE kept (add-only): CIDR`. OCI security lists keep duplicate entries too. R8 changes are additions only, so R8 runs use `--add-only`.
- **No hidden removals.** A full reconcile names each source it removes, as `REMOVE CIDR` in the step's description. Azure and GCP now read the rule they update (`az network nsg rule show --output json`, `gcloud compute firewall-rules describe --format=json`), so their plans show `add ...` and `REMOVE ...` like the others. Before this, an Azure or GCP update replaced the rule's whole source list without saying what it took out. A rule that already holds the wanted sources, protocol and port gets no step (`NO CHANGE`).
- **Error reasons.** A failed provider read now reports the last line of stderr (for a Python traceback, the exception) instead of the first line (`Traceback (most recent call last):`). The last 12 stderr lines go to the run log as `cloudctl: | ...`. When the cause is `Read-only file system`, the STOP line says the provider CLI cannot write its state directory under HOME: a read-only sandbox does this. `az` writes `~/.azure/az.sess` on every start.
- **Shared firewall scope.** Members share one firewall (and get their source sets united) only with the same provider, `scope=`, `account=`, `project=` and `region=`. Before this, ed209e and ed209j (both `scope=default`, in different GCP projects) were treated as one network, so each was planned as its own peer.
- **AWS CLI v1.** No more `--no-cli-pager`, which v1 rejects. Every `aws` command runs with `AWS_PAGER` set empty instead, which v1 ignores and v2 honours.

## Tests

```
rexx tests/test_cloudctl.rex CLOUDCTL_DIR SHIM LOGGING_PACKAGE_DIR
rexx tests/test_xtp.rex CLOUDCTL_DIR SHIM LOGGING_PACKAGE_DIR
rexx tests/test_column_display.rex CLOUDCTL_DIR
rexx tests/test_discover.rex CLOUDCTL_DIR SHIM LOGGING_PACKAGE_DIR
```

The tests make no cloud calls. They use dev4's own `cloud-fake` and `fake-gcloud-account.sh` unchanged, and cover:

- dev4's 37 `run.sh` cases
- PLAN/APPLY
- confirm, CIDR, port and unknown-option refusals
- the machine registry and the old `vultr restart ed209k` form
- Spot rules
- the ledger, `hours`, `check` and the events log

`test_xtp.rex` adds `tests/fixtures/xtp-fake`, which answers with grid-shaped AWS and OCI security-list state and hands everything else to dev4's fake. It covers:

- the slot matrix for all ten members
- refusals
- the AWS stale-source revoke
- the OCI camelCase rewrite
- Azure priorities and GCP target tags
- Vultr ranges
- APPLY and the ledger

`test_cloudctl.rex` also checks:

- a gcloud wrapper that fails without a message gives a visible rc, not silence;
- an unreadable rule state is refused, not planned as a create.

Every provider call is announced on stderr (`cloudctl: >` before, `cloudctl: < rc=` after), so a run is never a black box and stdout stays clean JSON.

`src/ColumnDisplay.cls` is the report table, used by `machines` and `accounts`. It started as a class from Gemini; its header lists the eight faults fixed.

`test_discover.rex` adds `tests/fixtures/discover-fake`. It lists ed209b's OCI instance first, so the a/b mapping must come from the address, and it puts ed209i's NSG on the subnet. It covers:

- every provider's discovery path
- fill, same and DIFFERS
- `--write` with backup, comments kept and differing values untouched
- `scope=none` in `xtp`
- refusals, including a missing CLI
- the ledger

`tests/fixtures/curl-fake` stands in for curl under `vultr-api.rex`. It fails any call whose key did not arrive on stdin, and the tests check that the key appears on no command line.

Result on 26 November 2026 (Ubuntu 22.04 build container, ooRexx 5): **101/101** (`test_cloudctl`), **98/98** (`test_xtp`), **30/30** (`test_discover`, whose fake now knows cats1 and cats2) and **15/15** (`test_column_display`). Three deliberate breakages (add-only off for named rules, AWS_PAGER not set, the read-only hint removed) were each caught. Earlier result, 7 November 2026: **101/101** (`test_cloudctl`), **61/61** (`test_xtp`), **30/30** (`test_discover`) and **15/15** (`test_column_display`) pass. A run of `vultr-api.rex` against a local listener with real curl confirmed the header, the body and the temporary-file clean-up.

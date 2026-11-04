# RexxOS Virtual UPS v0.3 — ED209 / KL10 research reference

**Status: locally tested standalone reference implementation.** No ED209 host deployment and no TOPS-20 guest attachment has been demonstrated. No external dependencies beyond Python 3.9+ on Linux. Authored files only: no historical media, native shared libraries, credentials or supplied guest images.

This is a *synthetic power-system model* useful for deterministic fault injection, portable service integration and eventual guest UPS emulation. Its readings are **not** live host power telemetry; it **never** calls `shutdown`, `reboot`, systemd, a cloud API, XTP or an actual UPS driver. It cannot stop or start an ED209 host or guest.

## Historical correction: the TOPS-20 `Waiting for UPS:` notice

The KLH10 installation guide (its `doc/klt20.txt` section 7) connects the recurring `[SCHEDULER]: Waiting for UPS:` notices to the guest's `MX` background process, started by `7-PTYCON.ATO`. It instructs the operator to identify and optionally log out that process. The notices **do not establish a missing hardware UPS interface**. Do not configure this Virtual UPS with the expectation that the notices will stop. Do not blindly run `LOGOUT` against the guest job; preserve guest evidence and operator authority.

References:
- https://github.com/PDP-10/klh10/blob/6d733f2a47644964492fd864454cbe1331655e53/doc/klt20.txt
- https://alt.sys.pdp10.narkive.com/r3CNrsyg/how-to-stop-tops-20-messages-sj-0-scheduler-waiting-for-ups

## Run locally

```bash
# From the extracted package directory. Set a private lab-owned path.
LAB="$HOME/kl10-oracle/virtual-ups"
python3 bin/virtual_ups.py --dir "$LAB" init --name ed209j-kl10 --simulate
python3 bin/virtual_ups.py --dir "$LAB" status
python3 bin/virtual_ups.py --dir "$LAB" signals

# Only simulated operations. These DO NOT affect Linux or KLH10 power.
python3 bin/virtual_ups.py --dir "$LAB" mains off --simulate
python3 bin/virtual_ups.py --dir "$LAB" advance 1440 --simulate
python3 bin/virtual_ups.py --dir "$LAB" events
python3 bin/virtual_ups.py --dir "$LAB" mains on --simulate
python3 bin/virtual_ups.py --dir "$LAB" advance 4800 --simulate
python3 bin/virtual_ups.py --dir "$LAB" audit
python3 bin/virtual_ups.py --dir "$LAB" snapshot > "$HOME/kl10-ups-snapshot.json"
```

The default synthetic system has a 100 Wh battery, a 200 W simulated load (30 minutes from full), a 60 W recharge rate, 20% low and 5% critical thresholds, full charge and mains initially present. `advance N` moves an **independent logical clock by N seconds**, not real time; the local machine remains powered normally. This is an example profile, not a claim about real DEC UPS hardware or electrical tolerances.

## Command-line interface

All commands accept `--dir <private-directory>` before the subcommand:

- `init --name NAME [--capacity-wh N] [--initial-wh N] [--load-w N] [--charge-w N] [--low-pct N] [--critical-pct N] --simulate`: initializes **only a previously uninitialized** local simulator. Refuses to overwrite evidence.
- `status`, `signals`, `events`, `audit`, `snapshot`: read-only JSON output.
- `mains on|off --simulate`, `load WATTS --simulate`, `advance SECONDS --simulate`: record synthetic changes and events.
- `rpc-stdio [--simulate]`: newline-delimited JSON-RPC 2.0 request/reply over standard input/output. No TCP/UDP/Unix socket listener, no external process actions.

`--simulate` is mandatory to modify a virtual power state and is deliberately distinct from a physical/effect authority. RPC mutations are disabled by default; notifications are ignored. Journal records form a SHA-256-linked, append-only replay chain. The journal is the simulation authority and is verified before every operation. Tampering or partial trailing records fail closed. `snapshot` is an audit export; **restore is not implemented** in v0.1. Preserve journal and snapshot together, with lineage.

## JSON-RPC 2.0 examples

```bash
LAB="$HOME/kl10-oracle/virtual-ups"
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"ups.status"}' \
  '{"jsonrpc":"2.0","id":2,"method":"ups.signals"}' \
  | python3 bin/virtual_ups.py --dir "$LAB" rpc-stdio

# Mutations require explicit --simulate; this still affects ONLY virtual power:
printf '%s\n' \
  '{"jsonrpc":"2.0","id":3,"method":"ups.mains","params":{"present":false}}' \
  '{"jsonrpc":"2.0","id":4,"method":"ups.advance","params":{"seconds":60}}' \
  | python3 bin/virtual_ups.py --dir "$LAB" rpc-stdio --simulate
```

Read operations: `ups.status`, `ups.signals`, `ups.events`, `ups.audit`, `ups.snapshot`. Mutation operations: `ups.mains {"present":bool}`, `ups.load {"watts":positive-integer}`, `ups.advance {"seconds":positive-integer}`. Every JSON-RPC request gets either `result` or `error`; requests without `id` deliberately have **no side effects**.

## ED209 placement

- Deploy the *model only* under a nonprivileged local account such as the existing KLH10 lab account on **ed209j**, in its own private directory. It can equally be tested on ed209d without interacting with COS.
- Run `python3 -m unittest discover -s tests -v` before adoption.
- Use `sshnode.sh --transfer ed209j <package.zip> <remote-zip>` and a normal verified remote extraction workflow if that helper is available at your operator workstation. Do not claim it has been transferred based on this artifact.
- No elevated privileges, firewall changes, TLS ports, containers, TAP interfaces, sshd changes, cron jobs, or systemd services are needed.
- Keep the power simulator separate from the KLH10 installation media, guest disks and historical `KL10_STATE/1` restore mechanisms.

## Acceptance

Validated here on a local Linux/Python runtime with eleven `unittest` tests, including deterministic discharge thresholds, chunk independence, recharge, synthetic-only flags, tamper detection, snapshot integrity, CLI consent, and RPC read-only gating.

**Not qualified:** ooRexx native service, Connect Selector wiring, Time Service live UTC correlation, Instrumentation Mesh event schema compatibility, KLH10 NI20, TOPS-20 electrical hardware adapter, any physical UPS integration or shutdown control.

See `docs/INTEGRATION.md` and `docs/CONTRACTS.md` for the next gates.

## v0.2 continuation (2026-10-23)

The previous report incorrectly treated TOPS-20's `Waiting for UPS:` as
unambiguous electrical hardware evidence. The pinned KLH10 installation guide
explicitly associates the recurring text with the `MX` process under `MAILS`
and recommends stopping the offending job or removing its startup invocation
from `7-PTYCON.ATO`. Neither a missing electrical UPS nor a failed email
transmission is established by the console excerpt alone.

New **read-only evidence command** (no initialized UPS state required):

```sh
python3 bin/virtual_ups.py inspect-tops20 --log path/to/guest-console.txt
```

The result `virtual.ups.guest-observation/1` records line numbers and explicitly
states that guest physical power state and mail delivery status are unknown.
The observation is *not* sent to the UPS model and never generates a synthetic
power event. Input is capped at 2 MiB; capture content is untrusted.

JSON journal and JSON-RPC decoding now reject duplicate keys and nonfinite
JSON constants. These are format-validation hardening only; SHA-256 chaining
remains integrity evidence, **not cryptographic authenticity** against an actor
able to replace all journal entries.

This package is a Python reference oracle. No native ooRexx service, physical
UPS adapter, KLH10 power-control adapter, Time Service/Instrumentation Mesh
runtime binding or ed209j deployment is claimed. See `sphere/` for continuity.

## v0.3 continuation (2026-10-29): provenance, admission declarations and bounded replay

- `capabilities` (CLI) / `ups.capabilities` (stdio JSON-RPC) is an effect-free, initialization-free declaration of actual features: reference Python, synthetic state only, no guest device, real host power, network listener, LDAP, TLS, Queue Fabric, Instrumentation Mesh, Time Service or Connect Selector binding. This is **not** an RPC endpoint or authorization integration.
- `inspect-tops20 --log ...` retains the SHA-256 digest and byte count of **raw** console evidence; strips ANSI/NUL artifacts **only from the analysis copy**. It reports exactly matching scheduler notices and nearby MAILS/OPR lines, while explicitly refusing to infer a failed email or an electrical UPS problem. No guest or live-host reads occur.
- Journal replay and append now fail closed at a bounded 64 MiB to prevent an unconstrained reference-process memory read. The bound is a reference-lab limit, not an architectural Storage Fabric value.
- Added five tests, for a total of **22 local passing unit tests**. Run `python3 -m unittest discover -s tests -v` and `./bin/run-demo.sh`.
- See `docs/OPERATIONS_HANDOFF.md` and the updated `sphere/` pack for evidence, infrastructure owner handoffs and unqualified acceptance gates. The autobuilder is not running; publication of this candidate is manual.

No native ooRexx implementation or live ed209 installation is claimed. v0.2 remains published unchanged as a separate revision.

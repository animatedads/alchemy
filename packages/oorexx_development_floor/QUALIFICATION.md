# Development Floor v0.1-dev13 qualification

Observed under the exact supplied runtime:

```text
Open Object Rexx Version 5.3.0 r13196 - Internal Test Version
Build date: Aug  3 2026
Addressing mode: 64
```

## New dev13 acceptance

- PASS every shipped `.cls` / `.rex` source under `rexxc`.
- PASS Luna planning JSON grammar and fail-closed shape validation.
- PASS Azure Luna discovery fixture with unique deployment selection, endpoint discovery, key retrieval, Secret Broker injection, and `/openai/v1/responses` wire path.
- PASS complete Luna project orchestration fixture: `PLAN -> IMPLEMENT -> deterministic evidence -> second bite -> REVIEW`.
- PASS final review decision `ACCEPT`; final stdout exactly `HELLO WORLD`.
- PASS final source SHA-256 `715f989ebee808fb6f4c9bce5a34b9f79639c32611d902ec4a802722bd29f576`.
- PASS project orchestration WLU consumption `3400000` micro-WLU.
- PASS provider registration distinguishes Luna's qualified Responses-v1 live path from the older API-version-query transport contract.
- PASS standards enforcer: 0 errors, 15 inherited warnings.
- PASS standards warning delta: current=15, allowed=15, resolved=0, new=0.

The user's separate live Azure execution evidence established the real logged-in Azure path before this package qualification: unique `luna` discovery selected `animatedadscy-7604-resource / gpt-6-luna`, the coding worker completed `HELLO WORLD`, and the mandatory second bite returned `KEEP`. This package does not embed or expose the Azure key.

---

# Development Floor v0.1-dev11 qualification

Observed under Open Object Rexx 5.3.0 r13196 (Internal Test Version, 64-bit).

## New dev11 acceptance

- PASS packaged dependency archive resolution with SHA-256 verification and no manually supplied `DF_*_ROOT` values.
- PASS OpenAI-compatible provider v0.6.1 with Secret Broker v0.2.
- PASS Azure `api-key` transport fixture.
- PASS llama.cpp loopback no-auth transport fixture.
- PASS external HTTP llama-compatible autonomous HelloWorld: first bite `HELLO WROLD`, deterministic mismatch evidence, second bite `REPLACE`, final `HELLO WORLD`, WLU settlement 2,200,000 micro-WLU.
- PASS Azure autonomous HelloWorld through Secret Broker `api-key` transport with exact deployment/API-version URL and no secret in argv; same deterministic second-bite repair and WLU settlement.
- PASS standards enforcer: 0 errors, 15 inherited warnings.
- PASS warning-delta ratchet: new=0.

These fixtures qualify the runnable provider boundaries and autonomous worker orchestration. They do not claim a live user Azure credential or live user llama.cpp process was contacted during package qualification.

---

# ooRexx Development Floor v0.1-dev10 qualification


## dev10 autonomous HelloWorld qualification

Under exact Open Object Rexx 5.3.0 r13196:

```text
PASS autonomous Development Floor HelloWorld
provider calls            2
initial source            compiles and runs, stdout HELLO WROLD
second bite               REPLACE from observed stdout mismatch
final stdout              HELLO WORLD
final source SHA-256      715f989ebee808fb6f4c9bce5a34b9f79639c32611d902ec4a802722bd29f576
WLU settled               2200000 micro-WLU
input tokens retained     50
output tokens retained    25
PASS Azure api-key transport
PASS llama.cpp loopback no-auth transport
```

The Azure/llama checks are controlled transport fixtures. They qualify header/no-auth behaviour and common AI Access semantics; they do not claim a live Azure key or live llama.cpp server was used.


## dev9 accounting/standards repair qualification

The dev8 accounting authority split is retained unchanged: WLU remains the sole work-entitlement authority and the Development Floor accounting ledger remains non-entitling.  dev9 repairs the five new accounting `PRIVATE_METHOD` advisories and the two identified reporting hot-path concerns without changing that authority boundary.

Observed under exact Open Object Rexx 5.3.0 r13196:

```text
PASS accounting codec helpers are package-local/activity-safe
PASS malformed hex ledger input fails closed without exception-driven decode flow
PASS resource totals rebuild from the durable append-only ledger after restart
PASS totalFor uses the derived totals index
PASS full WLU reservation/admission/consume/settle/refusal integration
PASS Alchemy Cloud Control dev2 seven-regression dependency suite
PASS specialist registry 113 logical / 127 revisions / 1,270 rules
PASS dog-food graph 53 classes / 255 methods
PASS documentation queue 308 segments
```

The standards enforcer reports `PASS`, `errors=0`, `warnings=15`.  A separate warning-delta gate compares warning fingerprints and multiplicity against `config/standards_warning_baseline.json`; new warnings fail qualification.  The five dev8 `WorkAccounting.cls` warnings are therefore resolved rather than grandfathered.

## Runtime

Qualified with the exact supplied runtime:

```text
Open Object Rexx Version 5.3.0 r13196 - Internal Test Version
Addressing mode: 64
```


## dev7 ED209K qualification override

ED209K / Kilo is deliberately selected for the pending RexxOS QEMU HELLO field run because it is the smallest current cloud node. Observed host evidence at registration time: active Debian x86_64, `qemu-system-x86_64` present, and 5.6 GiB free on `/`. General allocation remains `UNKNOWN`; QEMU is `OBSERVED_PRESENT`, not yet `QUALIFIED`, and host ooRexx smoke remains `UNVERIFIED`.

The explicit-qualification selector proves that Development Manager may select K while the ordinary `allocatable` predicate remains false. The pinned field harness is `rexxos_qemu_hello_deploy_v0.1-dev1`, SHA-256 `d732e0ab0b2e9c54e1c0b443b94da0a35e66099ffc3f3a3ff7010724860c022e`, with a 160-MiB / 1-vCPU guest. No field-run PASS is claimed in this package until the remote run actually produces its acceptance line.

## dev6 RexxOS appliance-profile registration

Development Floor pins and registers the supplied qualified RexxOS packages:

```text
rexxos_appliance_profiles_v0.1-dev2
SHA-256 e7f1c1ddf1336110a83137595cf142f68ffbf8f715eb62754aa3e8eb8628879b

rexxos_app_deploy_v0.1-dev3
SHA-256 8482f760c0d779b0c71d13ddc99b567c9b63cf90b344f93287005a4fe1de5062
```

The supplied package validation records the exact FAST verifier stack:

```text
Crypto v0.8.3
Runtime Reference v0.4
Foreign Runtime v0.22.6
foreign.openssl.crypto
openssl.libcrypto.hybrid.v2
OpenSSL /lib/x86_64-linux-gnu/libcrypto.so.3
private_key_capability = 0
```

The Development Floor does not reinterpret this as private-key service authority.
`REXXOS_FAST` is `QUALIFIED_DEFAULT`, `REXXOS_MINIMAL` is
`QUALIFIED_FALLBACK`, and `REXXOS_CRYPTO` remains
`REGISTERED_UNQUALIFIED_PRIVATE_KEY_SERVICE` for its distinct authority path.

The external package evidence reports 14.79 s for the MINIMAL crypto qualification
and 0.08 s for FAST on the supplied debug runtime, plus 0.21 s FAST sign/submit and
0.33 s App Server verification/staging. These are retained as observed evidence,
not scheduling guarantees.

## Activation boundary

The signed command deployment path remains deliberately bounded at:

```text
STAGED
```

The Development Floor now encodes the next lifecycle as an explicit contract:

```text
STAGED -> RECONSTRUCTED -> BOUND -> ACTIVE
```

Qualification proves that `STAGED` cannot be reported as `ACTIVE`, and the
registered RTO activation specialist is constrained to produce transition evidence
rather than collapsing the state machine.

## Registration qualification

```text
schema                 development.floor.registrations/0.4
bots                   10
control planes         1
provider accounts      7
execution providers    5
resource providers     11
deployment providers   2
appliance profiles     3
hosts                  10
allocatable hosts      5
```

The manager selects `REXXOS_FAST` as the qualified default for `REXXOS_QEMU` and
honours explicit selection of the qualified MINIMAL fallback.

## Specialist bootstrap

The qualified one-time bootstrap was imported during the final working-tree pass:

```text
logical specialists     113
profile revisions       127
domain rules           1270
```

## Alchemy Cloud Control dependency

Development Floor continues to pin `alchemy_cloud_control_v0.1-dev2.zip` and reruns
its seven ooRexx regressions under exact r13196 during the integrated framework pass.
No live cloud mutation or managed-node action is inferred from those local tests.

## Dog-food structural evidence

```text
source files             9
classes                 58
methods                274
Gwen documentation     332 segments
```

All framework Rexx source, tool and test files compile under `rexxc`. The complete
deterministic suite passes, including the new appliance-profile and activation-state
contracts, followed by regenerated source graph and documentation queue.

## Known boundary

The Network Lease provider remains `REGISTERED_INCOMPLETE`: current Cloud Control
can inspect firewall state but does not yet provide temporary firewall add/remove.
Cross-host test exposure therefore remains blocked until that mutation/revocation
surface is implemented and qualified.

## Portfolio standards enforcer

Claude's `oorexx_standards_enforcer.py` is run directly against the packaged dev10 candidate, followed by the warning-delta gate. The verdict is:

```text
PASS
errors   0
warnings 15
```

The advisory warnings are retained verbatim in
`state/standards_enforcer_report.json`; no ERROR finding is waived.

## dev8 WLU/accounting qualification

The dev8 acceptance adds an executable test against exact `work.load.units/0.12` with its
actual authenticated ledger.  The test must prove reservation, admission, consumption,
settlement/refund of unused work, entitlement exhaustion, refusal to execute without WLU,
and durable cross-resource accounting in native units.

Observed dev8 integration result under exact Open Object Rexx 5.3.0 r13196:

```text
PASS exact WLU reservation accepted
PASS WLU admission required before ACTIVE work
PASS actual WLU consumption recorded
PASS settlement charges actual work and refunds unused reservation
PASS entitlement exhaustion fails closed through WLU Authority
PASS execution without WLU reservation is refused
PASS WLU authenticated ledger verifies
PASS Development Floor accounting ledger replays durably
PASS input/output token and wall-time meters remain native units
PASS Alchemy Cloud Control dev2 seven-regression dependency suite
PASS specialist registry 113 logical / 127 revisions / 1,270 rules
PASS dog-food graph 51 classes / 251 methods
PASS documentation queue 302 segments
```

A separate attempt to run the WLU package's complete upstream suite reached the
Ed25519 checkpoint test and exceeded this environment's command wall limit in the
pure-Rexx crypto path.  That is not used as a failure or a pass claim here.  The
dev8 integration qualification exercises the exact WLU authority plus its
MAC-chained authenticated reservation ledger, while the external WLU package
retains its own pinned qualification provenance.


## dev16 reasoning alignment

Exact r13196 qualification covers: requested Luna low/concise reasoning summaries; 20,000-token planner/implement/review ceilings; persistence of claimed summaries; local Qwen semantic comparison; deterministic 0.70 threshold projection; a 0.23 fixture producing MISMATCH without conflating management alignment with code correctness; and the full Luna→Qwen→review orchestration fixture.

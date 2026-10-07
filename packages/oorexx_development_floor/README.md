# ooRexx Development Floor v0.1-dev16

Executable framework increment for a specialist-routed development operation.

## dev16: Qwen reasoning-alignment management

Development Floor now requests a concise claimed reasoning summary from Azure Luna (`reasoning.effort=low`, `reasoning.summary=concise`) while retaining a 20,000-token output ceiling. The raw provider envelope, claimed summaries, and token facts remain durable run evidence.

After a successful IMPLEMENT work item, a separate local Qwen management assignment receives only Development Floor's required reasoning obligations and Luna's claimed reasoning summary. Qwen returns bounded JSON containing a numeric `score` in `[0,1]` plus short `gaps`; it does not receive or grade private chain-of-thought. Development Floor owns the threshold (default `0.70`) and deterministically projects `MATCH` or `MISMATCH`. This score is management evidence and does not replace compile/run/acceptance evidence or independent review.

Persistent management artifacts are written under `management/`: required reasoning, claimed reasoning, Qwen request/response, and normalized reasoning-alignment result. The project summary now exposes `reasoning_score` and `reasoning_verdict`.

Default local management model: `qwen2.5-1.5b-npu` at `http://127.0.0.1:8008/v1/chat/completions`; both are environment-overridable.

## dev15: Luna-only planning session and sequential project execution

This cut deliberately freezes model routing to Azure `gpt-6-luna`. `run_project.sh luna [spec.json]` discovers the unique Luna deployment and key through the authenticated Azure CLI context, creates a WLU-accounted Development Floor planning session, asks Luna for a tightly validated two-item plan (`IMPLEMENT -> REVIEW`), then executes those items in order. The IMPLEMENT phase reuses the existing autonomous coding worker, including deterministic `rexxc`/execution evidence and mandatory second bite. REVIEW is a separate WLU-admitted Luna assignment that may return only `ACCEPT` or `REWORK`; it has no source mutation authority.

The first supplied project spec is `spec/hello_world_project.json`. The authoritative plan is retained as `project.plan.json` beneath the per-run workspace. Planning, implementation, and review token usage remain native accounting facts; WLU remains the sole work-entitlement authority.

This cut is qualified under the supplied exact ooRexx 5.3.0 r13196 internal-test runtime. The integrated suite now exercises the complete Luna orchestration transaction through a controlled Azure fixture: validated plan, IMPLEMENT first bite, deterministic ooRexx evidence, mandatory second bite, and independent REVIEW. The transaction finishes ACCEPT with exact stdout `HELLO WORLD`, source SHA-256 `715f989ebee808fb6f4c9bce5a34b9f79639c32611d902ec4a802722bd29f576`, and 3,400,000 micro-WLU consumed across planning, implementation, and review. The source standards gate introduces no new warning beyond the existing 15-warning baseline.



## dev11: runnable live worker + packaged dependency closure

The first autonomous coding worker is now a runnable entrypoint rather than only a deterministic in-process qualification. The delivered package carries the pinned dependency roots under `deps/`, so a fresh extraction no longer requires callers to assemble `DF_AI_ACCESS_ROOT`, `DF_WLU_ROOT`, Crypto, Alchemy Objects, Secret Broker or OpenAI-compatible provider paths by hand. Explicit `DF_*_ROOT` values still override the bundled copies for development.

With ooRexx available, the local-model proof is deliberately one command:

```bash
./run_worker.sh llama
```

The default endpoint is `http://127.0.0.1:8080/v1/chat/completions`. The wrapper queries `/v1/models` and selects the first advertised model when possible, creates a private per-run WLU key and evidence directory, admits the assignment, invokes the provider-neutral autonomous worker, runs deterministic ooRexx compile/execution evidence, performs the mandatory second bite, settles WLU and leaves the final source plus ledgers beneath `state/live-worker/`. `DF_MODEL` or the second command argument may explicitly select a model.

Azure uses the same worker:

```bash
export AZURE_OPENAI_ENDPOINT=https://YOUR-RESOURCE.openai.azure.com
export AZURE_OPENAI_DEPLOYMENT=YOUR-DEPLOYMENT
export AZURE_OPENAI_API_VERSION=YOUR-API-VERSION
export AZURE_OPENAI_API_KEY=...
./run_worker.sh azure
```

The key remains behind Secret Broker v0.2 and the trusted curl transport's `api-key` config boundary. The worker/model never receives credential, shell, filesystem, WLU or cloud authority.

Qualification now includes two external-transport autonomous HelloWorld runs. The llama fixture uses a real loopback HTTP OpenAI-compatible server; the Azure fixture uses the trusted transport boundary and verifies `api-key`, exact deployment/API-version URL, and no secret in argv. Both begin with `HELLO WROLD`, observe the deterministic stdout failure, make a second provider call, replace the source with `HELLO WORLD`, and settle 2,200,000 micro-WLU. These are transport/runtime fixtures, not claims that a live user Azure key or the user's live llama.cpp instance was contacted.

The OpenAI-compatible provider dependency is `v0.6.1`, a compatibility pin over v0.6 that records Secret Broker v0.2 (matching the Azure helper and `SecretLease~secretForTrustedConsumer` API) without changing request/reply or wire semantics.


## dev10: first autonomous coding worker + Azure/llama provider transports

The first bounded autonomous coding transaction is now executable. A coding assignment must already have specialist/execution binding and an admitted WLU reservation. The worker reads a bounded instruction file, sends a provider-neutral `AIProviderRequest`, accepts one structured single-file proposal, runs deterministic ooRexx compile/execution checks, performs one mandatory second bite using observed evidence, reruns the checks, records native token usage in the non-entitling accounting ledger, and settles WLU.

The model receives no shell, filesystem, cloud, provider credential, WLU, or deployment authority. It proposes JSON only; the worker owns the bounded workspace write and deterministic test.

The executable HelloWorld qualification intentionally starts with a valid-but-wrong program that prints `HELLO WROLD`. Deterministic evidence is fed to the second bite, which replaces it with `HELLO WORLD`. The final source SHA-256 is `715f989ebee808fb6f4c9bce5a34b9f79639c32611d902ec4a802722bd29f576`; two provider calls consume 2,200,000 micro-WLU in the fixture qualification and preserve reported token counts separately.

Provider transport is supplied by `ai.provider.openai-compat/0.6`:

- Azure OpenAI: explicit Azure deployment/API-version endpoint and Secret-Broker-backed `api-key` header.
- local llama.cpp: loopback-only OpenAI-compatible HTTP with `NONE` authentication.

Both transport modes pass r13196 fixture qualification. No live Azure credential or live llama.cpp runtime was exercised by this package, so registrations distinguish transport qualification from live-provider qualification.


## dev9: accounting warning repair and warning-delta gate

The five accounting-codec `PRIVATE_METHOD` warnings introduced in dev8 are repaired rather than accepted as permanent noise.  Codec and derived-index helpers now live on package-local classes with activity-safe public methods; they are not exported as public package classes.  Malformed hex fields are rejected by deterministic validation before conversion instead of using `SIGNAL ON SYNTAX` as normal decode control flow.

`DFAccountingLedger~totalFor()` now reads a derived in-memory totals index.  The index is rebuilt only from the append-only durable ledger on startup and updated only after durable append, so it is a reporting optimisation and never an entitlement source.

A new `development.floor.standards-warning-baseline/0.1` gate records the 15 inherited advisory fingerprints as visible backlog.  Qualification fails if a new warning fingerprint or occurrence appears.  Existing warnings may disappear without baseline edits.  This prevents a nominal `PASS` verdict from becoming permission for warning count to drift upward.

## dev8: WLU execution authority and durable accounting ledger

Substantive Development Floor work is now admitted through the exact `work.load.units/0.12` authority rather than merely registering WLU as a future resource.  The executable lifecycle is:

```text
assignment + bot/provider binding
        -> reserveDemand
        -> admit
        -> ACTIVE work
        -> consume
        -> settle or release
```

Binding a model, specialist, host or deployment provider is not permission to execute.  An admitted WLU reservation is required for substantive assignment work.  Deterministic observers/autotasks may use explicitly configured standing reservations, but their work is still accounted rather than treated as free.

`DFAccountingLedger` adds a durable `development.floor.accounting/0.1` journal correlated by assignment and WLU reservation.  It records native resource quantities without redefining them as WLU: input/output tokens, micro-currency, GPU seconds, wall/CPU time, bytes and future provider-specific meters stay in their own units.  This ledger is non-entitling; only WLU Authority may grant work.

The WLU package's own authenticated ledger remains the authority evidence for RESERVE/CONSUME/SETTLE/RELEASE.  The Development Floor journal is the cross-resource accounting projection used for cost, capacity and provider reporting.

## dev7: ED209K / Kilo smallest-machine field qualification target

ED209K is now explicitly registered as the smallest-machine RexxOS field-qualification canary. This is a **qualification override**, not general allocator promotion. Current observed evidence is Debian x86_64, `qemu-system-x86_64` present, and 5.6 GiB free on `/`; ooRexx host smoke and the actual RexxOS HELLO field result remain unqualified until the run completes.

The pinned field harness is `rexxos_qemu_hello_deploy_v0.1-dev1` (SHA-256 `d732e0ab0b2e9c54e1c0b443b94da0a35e66099ffc3f3a3ff7010724860c022e`). It runs a 1-vCPU, 160-MiB RexxOS guest and must end with `PASS RexxOS QEMU boot -> signed HELLO deployment -> RTO activation -> HELLO WORLD`. The harness requires either a RexxOS bzImage or a Linux source tree from which to build that kernel profile.

The Development Manager can explicitly select K for this bounded qualification while `host~allocatable` remains false. A successful field run may later supply evidence for normal allocator promotion; this cut does not pre-empt that result.

## dev6: qualified RexxOS appliance profiles and activation boundary

This cut pins and registers the qualified RexxOS FAST deployment path without moving provider knowledge into application code. `REXXOS_FAST` is now the qualified default RexxOS appliance profile; `REXXOS_MINIMAL` remains the qualified pure-Rexx fallback; `REXXOS_CRYPTO` remains a distinct private-key-authority profile and is not overclaimed as qualified for private-key service operation.

Pinned external packages:

```text
rexxos_appliance_profiles_v0.1-dev2
    SHA-256 e7f1c1ddf1336110a83137595cf142f68ffbf8f715eb62754aa3e8eb8628879b

rexxos_app_deploy_v0.1-dev3
    SHA-256 8482f760c0d779b0c71d13ddc99b567c9b63cf90b344f93287005a4fe1de5062
```

The qualified FAST verifier stack is `Crypto v0.8.3 -> Runtime Reference v0.4 -> Foreign Runtime v0.22.6 -> OpenSSL libcrypto.so.3`. The observed profile still has `private_key_capability = 0`: it verifies signed deployments quickly but is not provisioned as a private-key service.

The deployment authority boundary remains exact:

```text
STAGED -> RECONSTRUCTED -> BOUND -> ACTIVE
```

`STAGED` is not `ACTIVE`. The newly registered RTO activation specialist may work that sequence only when assigned and must retain evidence for every transition.

This cut binds the supplied **Alchemy Cloud Control v0.1-dev2** into the
Development Floor registration plane instead of duplicating its cloud/account/
transport semantics.

The authority chain is now:

```text
Development Manager / assigned infrastructure specialist
        |
        v
alchemy.cloud-control/0.1
   |        |        |
 SERVICE  RESOURCE   NODE
            |         |
        cloudctl.sh  sshnode.sh
            |
   gcloud-account.sh for GCP identity selection
```

`sshnode.sh` remains the only ED209 host command/file transport. Cloud Control
normalizes the request; it does not replace or copy the authoritative node
address/user/key map.

The supplied Cloud Control ZIP is pinned by SHA-256 in `DEPENDENCIES.md` and
was independently qualified for this integration under exact Open Object Rexx
5.3.0 r13196. No live cloud mutation or remote-node action is claimed by that
local qualification.

## Logical bot roles

The registered bot floor now contains:

- Development Manager;
- bounded package/domain coding specialist template;
- Gwen documentation specialist;
- independent CSM-style reviewer;
- specification authority;
- cloud-infrastructure specialist;
- deploy-to-test coordinator;
- deterministic zero-model-cost autotask runner;
- deterministic infrastructure observer;
- RTO activation specialist.

The cloud-infrastructure specialist may request registered Cloud Control,
managed-node and deployment operations only when assigned. Raw provider CLI and
raw SSH are explicitly outside its lane.

## One node object, many authorities

`InfrastructureProjection.cls` adds a read-only Odoo-style projection over the
otherwise divergent infrastructure evidence. A logical node retains stable object
identity while observations from Cloud Control, `sshnode.sh`, runtime probes and
future providers are refreshed independently.

Normal callers can work with one object:

```text
node~cloudState
node~reachable
node~freeSpace
node~memory
node~ooRexxVersion
node~qemuVersion
node~taskProcesses
node~firewall
```

The object does not erase disagreement. For example, Cloud Control may report
`RUNNING` while the latest `sshnode.sh` reachability observation is false. Both
observations remain attributable through the corresponding `DFObservedFact`; the
normalized convenience property follows an explicit source preference.

The projection is deliberately not a mutation authority. Restart, deployment,
firewall change and node operations still go back through the registered control
plane/resource providers.

### Firewall normalization

Ordinary callers see one `DFFirewallProjection` via `node~firewall`. It aggregates
normalized rules without forcing callers to remember whether a rule came from the
cloud perimeter or the host firewall. Provenance is retained as facets:

```text
CLOUD
LOCAL
GUEST_INTERNAL
```

Only infrastructure work that genuinely needs the distinction, such as swapping
internal rules for multiple RexxOS instances, needs to descend to a specific facet.

## Registration planes

The durable registration catalogue separates:

- logical bot role;
- persistent package/domain specialist identity and specialist revision;
- model/execution provider;
- provider account and funding source;
- control plane;
- physical/logical host;
- resource authority;
- deployment provider;
- RexxOS appliance profile and qualification state.

An assignment may bind independent identities:

```text
specialistId        = package/domain knowledge
botProfileId        = logical worker role/authority
executionProviderId = model/runtime for this assignment
```

Changing the model or host never creates a new specialist.

## Current ED209 allocation evidence

The current logical fleet registration contains ten nodes: A, B, C, D, E, H,
I, J, K and X. Node addresses are intentionally not copied into Development
Floor; `sshnode.sh` remains their authority.

Current allocation evidence registers B, C, D, I and J as available QEMU/ooRexx
hosts. A requires retry after its interrupted QEMU install attempt; E and X
retain unreachable status from the latest qualification evidence; H is
explicitly temporarily off; K is newly registered and remains unqualified until
its QEMU/ooRexx capability is actually observed.

Host-file membership therefore does not imply allocatability.

Provider-account registrations include logical declared accounts for OCI,
Azure, AWS and Vultr plus the two explicit GCP authorities. GCP retains the
strongest identity binding because Cloud Control currently has exact selectors
and expected principals for `bashqueue` and `animated-ads-cy`.

## Qualified specialist bootstrap registry

The one-time bootstrap still resolves to:

```text
127 qualified profile revisions
113 logical specialists
1,270 evidence-backed domain rules
```

Package revisions are retained as specialist revision history. Normal project
work consumes the current compact specialist profile plus the relevant source/
object-graph fragment rather than relearning a package from scratch.

## Deploy-to-test contract

The stable transaction remains:

```text
request resource set
-> allocate host
-> reserve WLU
-> assign QEMU
-> acquire temporary network lease when required
-> deploy / materialise exact test appliance
-> run test
-> collect evidence
-> clear down
-> revoke network lease
-> release WLU
-> release host
```

Cloud/node operations are now registered through `alchemy.cloud-control/0.1`.
The current Network Lease provider is deliberately marked **incomplete**:
`cloudctl.sh` can list firewall state but does not yet expose temporary firewall
add/remove. Development Floor therefore does not claim cross-host port leasing
is executable yet.

RexxOS remains `IMAGE_MATERIALISATION`: exact runtime, application/test code,
dependencies and test payload are built into the disposable QEMU appliance
before execution. `REXXOS_FAST` is the qualified default profile and
`REXXOS_MINIMAL` is the explicit fallback. `REXXOS_CRYPTO` is reserved for
private-key-authorised service work and is not selected merely because its API
can sign. Supported topology vocabulary is `SINGLE`, `PAIRED_RTO`, `FAILOVER`,
and `FORENSIC_FAILOVER`. The current application-deploy package still ends at
`STAGED`; reconstruction/binding/activation are the next separate authority
boundary.

## Dog-food qualification

```sh
OOREXX_ROOT=/path/to/oorexx/usr/local ./run_tests.sh
```

To re-run the qualified specialist import and registered Cloud Control dependency
in the same pass:

```sh
DF_SPECIALIST_BOOTSTRAP_ZIP=/path/to/specialist_bootstrap_qualified.zip \
DF_CLOUD_CONTROL_ROOT=/path/to/alchemy_cloud_control_v0.1-dev2 \
OOREXX_ROOT=/path/to/oorexx/usr/local \
./run_tests.sh
```


## dev15 durable run forensics

Every Luna project run now persists exact planning, implementation, deterministic evidence and review artifacts beneath its run root, plus an append-only `events.jsonl` built from ooRexx Logging v0.7 `LogEvent` objects. The final reviewer receives the complete acceptance list and final source, not only compile/run/stdout/SHA evidence. Secrets are intentionally excluded; Azure credential provenance is persisted only by reference.

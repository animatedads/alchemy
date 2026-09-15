# ooRexx AI Provider - Grok (xAI) v0.4

First-class Grok / xAI provider package qualified against the current Alchemy stack.

**Package release:** `0.4`  
**Public provider APIs remain:** `ai.provider.grok/0.3`, `ai.provider.grok.capability/0.3`, `ai.provider.grok.batch/0.3`, `ai.provider.grok.wlu/0.3`, `ai.provider.grok.batch.wlu/0.3`.

v0.4 is primarily a compatibility, authority-boundary and ooRexx-correctness release. It does not invent a new provider protocol merely because dependency versions advanced.

## Qualified dependency line

- `oorexx_ai_access_v0.6`
- `oorexx_secret_broker_v0.2`
- `alchemy_objects_v0.8`
- `oorexx_crypto_v0.1` (required transitively by Alchemy Objects)
- optional WLU path: `runtime_registry_v0.14` + `oorexx_work_load_units_v0.12`

## What this package answers

1. **How do I call a Grok model?** — real-time chat plus Batch API.
2. **Which model/channel should this workload use?** — deterministic capability selector and cost optimiser.
3. **How is batch work metered differently from real-time?** — distinct WLU facts, long TTL and deferred delivery rate.
4. **Where do provider credentials live?** — behind Secret Broker references and short-lived leases; the provider never stores the raw credential as configuration.

## Capability selector

```rexx
sel = .GrokCapabilitySelector~new
job = .GrokWorkloadProfile~new("ECONOMY", "ANY", .true, 500000, 20000)
plan = sel~selectModel(job)
say plan~modelId
say plan~useBatch
say plan~estimatedMicroUsd
```

Selection is fail-closed:

1. enforce the declared capability tier floor (`ECONOMY` < `STANDARD` < `FRONTIER`);
2. enforce channel/data-zone requirements;
3. prefer batch only when the workload permits it and the model/channel support it;
4. choose the cheapest remaining route;
5. raise if no candidate survives — never silently lower tier or sovereignty constraints.

The built-in catalogue is a deployment default, not an immutable pricing authority. Deployments may supply a replacement `GrokModelCatalog`.

## Secret Broker v0.2 boundary

Real-time and Batch paths now use the current broker contract:

```text
credential reference
      |
      v
SecretBroker~acquire()
      |
      v
SecretLease
      |
      +-- secretForTrustedConsumer()   only inside trusted transport
      |
      +-- retire()                     after request / exception
```

The real-time and Batch curl transports materialize the Authorization header in a temporary mode-0600 curl configuration. Secret values are not placed on argv and are excluded from Alchemy instrumentation.

Model/output/request-count policy executes before credential acquisition. A rejected model therefore cannot cause an otherwise unnecessary secret lease.

## Alchemy Objects v0.8

All direct Grok behavioural objects use preferred non-legacy construction (`self~init:super(...)`) and complete STANDARD metadata. The acceptance suite verifies:

- STANDARD adoption succeeds;
- zero adoption warnings;
- zero reserved-base overrides;
- construction provenance is `INIT`;
- trusted HTTP transport methods are declared `PROTECTED` security boundaries.

The provider/runtime objects inherited from AI Access v0.6 retain the same preferred construction path.

## Real-time path

- endpoint default: `https://api.x.ai/v1/chat/completions`
- credential reference default: `xai-api-key`
- mapped environment default: `XAI_API_KEY`
- WLU facts: `AI_INPUT_TOKEN`, `AI_OUTPUT_TOKEN`
- WLU planner is conservative and intentionally tokenizer-inexact; actual provider usage remains settlement evidence.

## Batch path

```text
create -> add requests -> poll -> results / cancel
```

Batch has a distinct workload shape:

| | Real-time WLU | Batch WLU |
|--|---------------|-----------|
| Facts | `AI_INPUT_TOKEN`, `AI_OUTPUT_TOKEN` | `AI_BATCH_REQUEST`, `AI_BATCH_INPUT_TOKEN`, `AI_BATCH_OUTPUT_TOKEN`, `AI_BATCH_CREATE` |
| Default target / TTL | short | `86400 / 90000` |
| Delivery rate | normal | `0` (deferred) |
| Admission | before completion | before add-requests |
| Credential acquisition | after policy | after policy |

v0.4 additionally exercises the Batch provider itself. This caught and fixed a latent ooRexx defect in v0.3 where the special Rexx variable `RESULT` had been used as a mutable Directory.

## Authority boundaries

- Provider-facing requests are narrow AI Access value objects.
- Runtime Registry retains runtime-generation/Ability authority.
- WLU retains valuation, admission, capacity and settlement authority.
- Secret Broker retains credential-resolution authority.
- Capability selection and WLU planners carry no provider secret or HTTP authority.
- Alchemy instrumentation records bounded metadata, never prompt or secret contents.

## Sources

| File | Role |
|------|------|
| `src/GrokCapability.cls` | catalogue, workload profile, selector, routing plan and channel |
| `src/GrokProvider.cls` | real-time adapter, curl transport and runtime module |
| `src/GrokWLU.cls` | real-time WLU planner |
| `src/GrokBatchProvider.cls` | Batch API adapter and trusted transport |
| `src/GrokBatchWLU.cls` | Batch WLU planner |

## Acceptance markers

```text
GROK ALCHEMY V0.8 ADOPTION: OK
GROK CAPABILITY SELECTOR V0.4: OK
GROK PROVIDER V0.4: OK
GROK RUNTIME MODULE V0.4: OK
GROK BATCH PROVIDER V0.4: OK
GROK BATCH CURL V0.4: OK
GROK REAL CURL: OK
GROK WLU PLANNER V0.4: OK
GROK WLU HTTP V0.4: OK
GROK BATCH WLU PLANNER V0.4: OK
```

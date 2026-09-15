# ooRexx AI Provider - Anthropic v0.2

Anthropic provider for `oorexx_ai_access_v0.6`, plus a capability selector
and cost optimizer that pick a model/channel/region from a description of
the *workload*, not from a caller-supplied model name.


## v0.2 current credential boundary

Both direct real-time and Messages Batch transport now use `SecretBroker~acquire(reference)`, materialize the value only through `SecretLease~secretForTrustedConsumer()` inside the trusted curl boundary, and retire the lease immediately after curl returns. The API key is written only to the temporary mode-0600 curl configuration and never placed on curl argv. `AnthropicCredentialSource` remains only as a compatibility adapter for callers that still pass an environment-variable name; provider execution itself no longer resolves that environment variable directly.

`AnthropicCapabilitySelector`, `AnthropicProvider`, and `AnthropicBatchProvider` are qualified against Alchemy Objects v0.8. The selector and Batch provider use preferred `self~init:super(...)` construction; the real-time provider inherits the current AI Access v0.6 base. The acceptance test requires STANDARD adoption, zero warnings, no reserved-base override and `INIT` construction provenance.

The Batch implementation also avoids the ooRexx special variable name `RESULT` for transport outcomes and is now exercised by the same Secret Broker/fake-curl fixture as real-time transport.

## The actual point of this package

Every other provider package in this line answers "how do I call model X".
This one additionally answers "which model should this job even use" --
and it is built specifically so the answer is not always "the biggest one
available":

```rexx
sel = .AnthropicCapabilitySelector~new

/* a high-volume, low-complexity, batch-tolerant job */
job = .AnthropicWorkloadProfile~new("LOW", "ANY", .true, 500000, 20000)
plan = sel~selectModel(job)
say plan~modelId          -- claude-haiku-4-5-20251001, not Fable
```

The selector's rule, in one place, deliberately hard to route around:

1. Filter candidate models to those whose **capability tier** meets the
   workload's stated floor (`LOW` / `STANDARD` / `FRONTIER` / `RESEARCH`).
2. Filter candidate (model, channel) pairs to those whose **channel/region**
   satisfies the workload's stated data-sovereignty zone.
3. Of what survives both filters, pick the **cheapest**. Batch is used
   whenever the workload allows it and the model/channel support it.
4. If nothing survives, raise -- never silently substitute a cheaper tier,
   a different zone, or serve from a channel that fails the sovereignty
   requirement.

A workload only reaches Opus/Fable-class models by declaring it genuinely
needs `FRONTIER`/`RESEARCH`-tier capability. Nothing defaults there.

## Data sovereignty is a real constraint here, not a label

Anthropic's own direct API (`api.anthropic.com`) has no first-party
EU/region-locked processing option -- it is US infrastructure, full stop.
Genuine regional control comes from AWS Bedrock or Google Vertex AI, where
region is a property of the endpoint you call (Bedrock EU options include
`eu-central-1` Frankfurt, `eu-west-1` Ireland, `eu-west-3` Paris; Vertex has
its own EU regions). `AnthropicChannel` models this directly: a channel
carries a `zone` (`US` / `EU` / ...), and the selector will not route a
workload whose `requiredZone` is `EU` through a channel whose zone is `US`,
regardless of cost. See `tests/test_capability_selector.rex` cases 3-4b for
this being exercised, including the honest failure case: the newest
research-tier model isn't available outside the direct channel yet, so a
`RESEARCH`+`EU` workload correctly raises rather than getting quietly served
from the US.

## Cost optimizer / cost query

- `estimateCost(modelId, inputTokens, outputTokens, useBatch)` -- deterministic
  estimate from the model catalog's rate card, batch discount applied
  automatically for batch-eligible models.
- `rankCandidates(profile)` -- every eligible (model, channel) pair, cheapest
  first, so a caller can see the tradeoff instead of just the winner.
- `recordJobCost` / `queryJobCost(jobId)` -- a job ledger so a caller can ask
  "what did/will this job cost" after the fact. `AnthropicBatchProvider`
  records an estimate at `createBatch` time and a caller can call
  `settleJobCost` once real usage is known, to replace the estimate with
  the actual billed figure.

The rate card in `AnthropicModelCatalog~init` is illustrative placeholder
pricing, clearly labelled as such in the source. It is a shape for an
operator's real rate card, not a claim about current Anthropic/Bedrock/
Vertex pricing -- replace it via `registerModel` with real figures before
using this for actual spend decisions.

## API routes this package actually calls

| Operation | Method | Path |
|---|---|---|
| Completion | POST | `/v1/messages` |
| Create batch | POST | `/v1/messages/batches` |
| Get batch | GET | `/v1/messages/batches/{id}` |
| List batch results | GET | `/v1/messages/batches/{id}/results` |
| Cancel batch | POST | `/v1/messages/batches/{id}/cancel` |

Headers: `x-api-key`, `anthropic-version: 2023-06-01`. Batch discount is
50% off matching real-time pricing, 24h hard timeout, up to 100,000
requests/256MB per batch, results retained 29 days -- these are Anthropic's
published batch terms, not this package's invention.

## Files

- `src/AnthropicProvider.cls` -- `AnthropicChannel`, `AnthropicModelCatalog`,
  `AnthropicWorkloadProfile`, `AnthropicRoutingPlan`,
  `AnthropicCapabilitySelector` (the actual deliverable);
- `src/AnthropicTransport.cls` -- `AnthropicProvider` (real-time,
  subclasses `AIProviderAdapterBase`) and `AnthropicBatchProvider`
  (batch CRUD), both live-capable against the direct channel;
- `tests/test_capability_selector.rex` -- 9 assertions on selection logic,
  no network required;
- `tests/test_transport_loads.rex` -- structural check that the transport
  classes construct and fail closed without credentials, no network
  required;
- `tests/test_secret_broker_transport.rex` -- deterministic real-time + Batch
  credential-boundary test using a fake curl executable; verifies no secret on
  argv, mode-0600 curl configuration, expected `x-api-key` materialization and
  deterministic lease retirement.
- `tests/test_alchemy_v08_adoption.rex` -- STANDARD adoption for selector,
  real-time provider and Batch provider, requiring zero warnings and preferred
  `INIT` construction provenance.
- `tests/test_real_wire.rex`, `tests/test_real_batch_wire.rex` -- optional live
  network probes. A provider-domain authentication error is endpoint evidence;
  `AI_ANTHROPIC_TRANSPORT` is explicitly reported as UNPROVEN rather than being
  mislabelled as a successful endpoint round-trip.

## Required external packages

- `alchemy_objects_v0.8` (`AlchemyObject.cls`, `AlchemyAdoption.cls`)
- `oorexx_ai_access_v0.6` (`AIProviderAccess.cls`) -- needed for the real-time provider adapter.
- `oorexx_secret_broker_v0.2` (`SecretBroker.cls`) -- credential acquisition/lease authority for both real-time and Batch transport.
- `oorexx_crypto_v0.1` (`crypto.cls`) -- transitive Alchemy/Secret Broker cryptographic dependency.
- `curl`, and ooRexx's `rxunixsys` library (for `sysMkDir`/`sysFileDelete`
  used by the temp-file handling around curl config files)

```sh
REXX=/path/to/rexx \
ALCHEMY_OBJECTS_ROOT=/path/to/alchemy_objects_v0.8/src \
AI_ACCESS_ROOT=/path/to/oorexx_ai_access_v0.6/src \
SECRET_BROKER_ROOT=/path/to/oorexx_secret_broker_v0.2/src \
CRYPTO_SRC=/path/to/oorexx_crypto_v0.1/src \
./run_tests.sh
```

Set `ANTHROPIC_API_KEY` to additionally exercise the optional live-network
probes. A transport failure does not certify endpoint reachability; the tests
print `UNPROVEN` in that case. The v0.2 release qualification relies on the
deterministic fake-curl credential-boundary test rather than assuming external
network availability.

## Scope deliberately not added here

- AWS SigV4 / GCP OAuth signed transport for the Bedrock/Vertex channels.
  Those channels are fully modeled for selection, routing and cost purposes
  -- a workload requiring EU residency is correctly routed to them and never
  silently served from the US-only direct channel -- but v0.2 only ships a
  working *live* transport for the direct channel. Executing a Bedrock/Vertex
  `AnthropicRoutingPlan` is a separate authority boundary (credential kind,
  signing, and per-cloud request shaping all differ) and belongs in its own
  package, the same way this line already separates provider adapters from
  the tool broker and from secret storage.
- cloud-specific credential signing for Bedrock/Vertex. Direct-channel API-key material is now acquired through `oorexx_secret_broker_v0.2`; the environment mapping supplied by `fromEnvironment` contains only the secret reference -> environment-variable name, and provider execution uses a short-lived `SecretLease`.
- MCP/tool-call brokerage, streaming response transport -- same reasoning
  as the sibling packages: separate authority boundaries, separate packages.

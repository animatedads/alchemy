# Changelog

## v0.4

- Requalified the unchanged generation-stamped tool authority boundary against AI Access v0.5, Alchemy Objects v0.7 and Work Load Units v0.11.
- Preserved stale-offer refusal, one-shot/cancellable tickets, exact Runtime Registry v0.13 pinned execution and WLU denial before dynamic tool invocation.
- No provider, Secret Broker, network or conversation authority was added.

## 0.3

- Advanced the provider-neutral DTO dependency to AI Access v0.4.
- Requalified the unchanged generation-stamped offer/ticket authority model against structured-message-capable AI Access.
- Deliberately added no conversation/provider/network/secret behavior to the privileged broker.
- Retained Runtime Registry v0.13 pinned canonical execution and optional WLU v0.3 admission/settlement behavior.

## 0.2
- Added `AIToolOffer`, a plain generation-stamped non-authority value carrying model-safe `AIProviderToolDefinition` values.
- Added `AIToolBroker~offer()` to derive definitions from the exact active Ability input schemas and release the temporary session before model inference.
- Added `AIToolProposal~fromProviderCall()` and `AIToolBroker~prepareOffered()` for provider-neutral `AIProviderToolCall` values.
- Added stale-offer refusal: if the active Ability generation changed during inference, preparation returns `AI_TOOL_OFFER_STALE` and releases the newly acquired session.
- Added not-offered refusal distinct from the catalog allowlist, preventing a provider from requesting a tool it was not shown.
- Added AI Access v0.3 as a required value-contract dependency without introducing any provider/network dependency.
- Extended WLU acceptance so success and capacity-denied calls both travel through generation-stamped offers.
- Offer instrumentation records generation/count/status only; model-visible schemas and tool arguments remain absent from Alchemy evidence.

## 0.1
- Added explicit model-visible `AIToolCatalog` allowlist with private tool-name to Runtime Registry Ability-id mapping.
- Added detached `AIToolProposal` JSON value boundary so later nested caller mutation cannot change approved arguments.
- Added one-shot `AIToolTicket` which owns an exact held `AbilitySession` generation lease across proposal/approval delay.
- Added canonical dispatch through Runtime Registry v0.13 `routePinnedAbility` rather than duplicating Ability schema/WLU/settlement logic.
- Added explicit cancellation and held-session cleanup, including visible release-failure state.
- Added detached `AIToolDispatchResult` business value and execution metadata surfaces.
- Added WLU admission-denial mapping with HTTP 429/retry evidence while retaining pre-execution denial semantics.
- Added Alchemy Objects v0.4.3 contracts/instrumentation for catalog, broker and ticket while keeping DTOs plain.
- Added generation-pinning acceptance: a ticket prepared on V1 executes V1 after V2 activation; a new ticket executes V2.
- Added allowlist, schema-denial, one-shot, cancellation, deep-detachment and argument non-disclosure acceptance.
- Added WLU v0.3 acceptance proving 100,000 micro-WLU actual settlement and capacity denial before dynamic tool execution.

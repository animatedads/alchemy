# ooRexx AI Tool Broker v0.4

v0.4 requalifies the unchanged generation-stamped tool authority boundary against AI Access v0.5, Alchemy Objects v0.7 and WLU v0.11. It intentionally adds no conversation, provider, Secret Broker or network behavior.

## Authority flow

```text
AIToolBroker.offer()
  -> short-lived active AbilitySession
  -> exact Ability input schemas
  -> AIToolOffer(generation stamp + model-safe AIProviderToolDefinition[])
  -> session released before inference

provider-neutral AIProviderToolCall
  -> prepareOffered() reacquires current generation
  -> generation equality + allowlist + schema validation
  -> one-shot AIToolTicket holds exact AbilitySession
  -> execute() -> Runtime Registry v0.13 routePinnedAbility()
```

The model sees only name/description/input schema. It never sees the private Ability id or generation stamp. If deployment changes while inference is in flight, `prepareOffered()` returns `AI_TOOL_OFFER_STALE` and retains no lease.

`AIToolTicket` remains the sole authority-bearing object and is one-shot/cancellable. Tool arguments are deeply detached. Business results and WLU execution evidence remain separate.

## Dependencies

Required:
- Runtime Registry v0.13 / Ability HTTP v0.7
- AI Access v0.5, for plain provider-neutral tool DTOs only
- Alchemy Objects v0.7
- shared Crypto v0.1

Optional qualification:
- Work Load Units v0.11

The broker has no provider-specific, Secret Broker or network dependency.

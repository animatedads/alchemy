# LLMPA directory-loaded named abilities

`abilities.d/*.cls` is the trusted semantic tool extension surface for LLMPA.

The runtime scans the directory, loads each ooRexx package with `Package~new()`, inspects `publicClasses`, and instantiates only classes that subclass `LlmPaAbility`.  Adding a new ability therefore does not require editing a central parser/dispatcher table.

The directory is a **trusted code boundary**, not a data directory.  Loading an ability grants no machine authority by itself.  Each descriptor declares its semantic authority class and whether it mutates state.  Actual filesystem/process/network mechanics remain delegated to injected platform/provider services.

## Descriptor contract

Every ability supplies:

- `ability_id`
- `version`
- `description`
- aliases
- `authority_class`: `READ_ONLY`, `EVIDENCE_ONLY`, `ADVISORY`, or `GOVERNED_MUTATION`
- `mutating`
- request schema identity
- response schema identity
- primitive requirements

The registry fails closed on missing metadata, malformed names, duplicate ability IDs, or duplicate aliases.  There is no last-file-wins rule.

## Invocation

Direct governed tool surface:

```text
pa-tool abilities [FILTER]
pa-tool ability ABILITY_ID [JSON_OBJECT]
pa-tool plan current
pa-tool continuity current
```

Existing package commands remain available, but resolve through the same registry in `pa-tool`:

```text
pa-tool package stage ZIP
pa-tool package release-analyse DIR [DECISIONS.json]
pa-tool package release DIR [DECISIONS.json]
```

The Queue-backed LLMPA command surface adds:

```text
llmpa abilities [FILTER]
llmpa ability ABILITY_ID [JSON_OBJECT]
llmpa plan current
llmpa continuity current
```

`ability.catalogue` means Codex no longer has to guess command names after compaction or process restart.

## Structured Response boundary

`LlmPaAbilityRegistry` does **not** define another Structured Response API.

An ability returns its domain result plus optional `cognitiveEffects` proposals.  The registry creates a detached `llm.pa.ability.execution/0.1` record.  If the caller injects a service named `structured_response_emitter`, that service receives the execution record and request and owns projection into the estate Structured Response producer contract.

This preserves the important boundary:

```text
ability execution
    -> detached semantic execution record
    -> Structured Response producer
    -> cognitive proposals
    -> Cognitive Admission
```

Model/ability cognitive effects are proposals, never authority and never direct journal writes.

## Cognitive continuity rule

`continuity.current` deliberately labels the existing generated continuity brief `PROJECTION_ONLY`.  The brief is not AI Memory authority and may be regenerated.  Durable cognitive state, once the Cognitive Continuity service is integrated, must not be subject to model-context compaction criteria.

Inference context may compact. Cognitive state persists.

## Primitive-provider seam

Abilities describe mechanics they need, rather than owning shell syntax.  For example, `package.stage` declares:

```text
filesystem.capacity
archive.inspect
archive.extract
digest.sha256
filesystem.atomic_publish
```

Those names are intentionally ready for the common POSIX/process/archive/Crypto platform work being implemented elsewhere.  The ability remains the semantic/governance layer; the platform provider owns OS mechanics.

## Cognitive Continuity module

Candidate4 adds `abilities.d/CognitiveAbilities.cls`, which consumes the sealed
`oorexx.cognitive.continuity/0.1` dependency.  The module is discovered exactly
like every other ability module; no central command-dispatch table was extended.

Use `pa-tool abilities cognitive` to inspect the current descriptors.  The most
important dog-food operation is `cognitive.context.export`: it returns both the
exact `cognitive.model-context/0.1` feed and the reason trace used to construct
that disposable projection.  `cognitive.effects.propose` is the only cognitive
write ability and remains a governed proposal surface: actor and authority
classification are server-derived.

See `COGNITIVE_ABILITIES.md` for the full boundary.

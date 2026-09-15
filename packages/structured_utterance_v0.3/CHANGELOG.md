# Changelog

## 0.3 qualification repair - 2026-08-24

- Seals `BrandExperienceContext` with its owning `StructuredUtterance`, preventing canonical evidence and downstream bridge tags from drifting after utterance seal.
- Adds a regression proving post-seal domain/function/opportunity mutation is rejected and canonical text remains stable.
- Makes the v0.3 native bridge fail explicitly with `INTERACTION_NATIVE_TOKEN_INCOMPATIBLE` for legacy free-form identities that cannot satisfy Interaction Event opaque-token fields, instead of leaking an ooRexx syntax condition.
- Corrects the native bridge dependency to Interaction Event v0.3 and records successful qualification against Alchemy Objects v0.8 and Runtime Registry v0.14.
- No constructor or public evidence-field shape changes; API remains `structured.utterance/0.3`.

## 0.3 - 2026-08-23

- Upgrades the optional bridge to Interaction Event v0.2 native generation-evidence objects.
- Emits first-class information-use evidence including source privacy, target act, relation role, declared use and effective use.
- Emits first-class generation-intent evidence including intended act/register/outcome and linked information-use ids.
- Emits first-class derived findings with controlled evidence references.
- Retains compatibility `STRUCTURED_INTENT/...` and `STRUCTURED_FINDING/...` tags for routing, but they are no longer the only persisted evidence.
- Adds a cross-act regression where sensitive recovery context justifies a generic extra-bag sales sentence; raw sensitive prose is removed while native intent/use evidence survives projection.
- Runtime API is `structured.utterance/0.3`; v0.2 constructors and analysis semantics remain compatible.

## 0.2 - 2026-08-23

- Adds first-class communicative acts, information-use edges and generation intent.
- Adds structural effective-use derivation and sensitive commercial-repurposing / declared-use-mismatch findings.
- Adopts Alchemy Object v0.4.3 for the canonical Structured Utterance object.

## 0.1

- Initial pre-flattening semantic-purpose, lineage, privacy and brand-context model.

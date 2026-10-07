# Proposed COG semantic registration seam

## Goal

COG currently owns recipes, parameters, context, plan freezing and execution. Symbolic NLP should not duplicate those responsibilities.

The proposed seam is for a recipe to expose optional semantic registration data alongside its existing execution definition.

Conceptually:

```json
{
  "id": "COPY_FILE",
  "semantics": {
    "verbs": ["COPY"],
    "nouns": ["FILE"],
    "slots": [
      {"name": "source", "markers": ["from"], "mode": "PHRASE", "stop": ["to"], "required": true},
      {"name": "destination", "markers": ["to"], "mode": "REST", "required": true}
    ]
  }
}
```

Canonical concepts can be registered separately:

```json
{
  "concepts": [
    {"id": "COPY", "role": "VERB", "terms": ["copy", "duplicate"]},
    {"id": "FILE", "role": "NOUN", "terms": ["file", "document"]}
  ]
}
```

This is a proposed contract, not a claim that existing COG JSON already has these fields.

## Why this is preferable to importing regex

A Python regex pattern is an implementation artifact. It does not cleanly expose:

- which word is the semantic action;
- which word is the object;
- which aliases share one meaning;
- which preposition binds which parameter;
- which missing parameter should reduce confidence;
- why two recipes competed.

The semantic registry makes those facts first-class while allowing existing regex matching to remain as a compatibility path during migration.

## Suggested migration sequence

1. Keep current COG recipe execution and governance unchanged.
2. Add optional semantic metadata to a small set of recipes.
3. Register that metadata into `SymbolicNLPParser` during COG startup.
4. Compare symbolic candidates against existing deterministic regex candidates.
5. Log disagreements as evidence; do not silently switch execution semantics.
6. Once qualified, allow symbolic resolution to propose the same existing recipe IDs.
7. Keep COG's context filtering and frozen-plan acceptance after semantic resolution.

## Example discrimination

Two recipes can share the same basic vocabulary:

```text
LIST_DIR_CURRENT := LIST + DIRECTORY
LIST_DIR_PATH    := LIST + DIRECTORY + required PATH introduced by IN
```

The symbolic calculation then distinguishes:

```text
list directory
    -> LIST_DIR_CURRENT

list directory in src
    -> LIST_DIR_PATH(PATH=src)
```

No unrestricted language model is needed for this distinction and no action is executed by the parser.

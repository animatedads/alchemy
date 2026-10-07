# ooRexx Symbolic NLP v0.1-dev2

A small, self-contained symbolic NLP and semantic intent parser written in native ooRexx.
It is intended to sit beside COG, Librarian-style lexical examination, NewShell and other components that own command vocabularies.

The component does **not** execute commands. It identifies registered meaning and returns evidence that another component can inspect, govern and act upon.

## What dev2 adds

Dev1 proved the compact deterministic intent calculation. Dev2 makes the semantic layer compositional:

- reusable **verb and noun concepts** with registered synonyms;
- intent definitions expressed in terms of those concepts;
- `NEXT`, `REST` and `PHRASE` argument grammars;
- quoted multiword arguments;
- configurable stop markers for prepositional arguments;
- required-slot evidence as part of intent selection;
- token-index-safe scoped negation;
- a compact semantic graph and inspectable logical form;
- dev1 registration API retained for compatibility.

No statistical model, Python runtime, POS tagger or external NLP library is required.

## Concept registration

```rexx
parser = .SymbolicNLPParser~new

parser~registerConcept("CREATE", "VERB", "CREATE|MAKE|DEFINE")
parser~registerConcept("CLASS",  "NOUN", "CLASS|TYPE")

parser~registerSemanticIntent("OOREXX_CREATE_CLASS", -
    "CREATE", "CLASS", "OOREXX CLASS", 100)

parser~registerSlot("OOREXX_CREATE_CLASS", -
    "CLASS_NAME", "NAMED|CALLED", "PHRASE", 1, "WITH|IN|USING")
```

Parsing:

```text
create an ooRexx class called "Invoice Line" with no methods
```

returns a semantic form equivalent to:

```text
OOREXX_CREATE_CLASS[POSITIVE](ACTION=CREATE;OBJECT=CLASS;CLASS_NAME="Invoice Line")
```

`no methods` does not negate the command because polarity is scoped to the matched command verb.

## Prepositional slots

A command owner can state its argument grammar explicitly:

```rexx
parser~registerConcept("COPY", "VERB", "COPY|DUPLICATE")
parser~registerConcept("FILE", "NOUN", "FILE|DOCUMENT")
parser~registerSemanticIntent("COPY_FILE", "COPY", "FILE", "", 90)
parser~registerSlot("COPY_FILE", "SOURCE", "FROM", "PHRASE", 1, "TO")
parser~registerSlot("COPY_FILE", "DESTINATION", "TO", "REST", 1)
```

```text
copy file from README.md to backup/README.md
```

becomes:

```text
COPY_FILE[POSITIVE](ACTION=COPY;OBJECT=FILE;SOURCE=README.md;DESTINATION=backup/README.md)
```

## Slot evidence and closely related commands

Closely related commands can share verbs and nouns while differing by argument grammar:

```rexx
parser~registerSemanticIntent("LIST_DIR_CURRENT", "LIST", "DIRECTORY", "", 90)
parser~registerSemanticIntent("LIST_DIR_PATH",    "LIST", "DIRECTORY", "", 95)
parser~registerSlot("LIST_DIR_PATH", "PATH", "IN", "REST", 1)
```

The resulting calculations distinguish:

```text
list directory          -> LIST_DIR_CURRENT
list directory in src   -> LIST_DIR_PATH(PATH=src)
```

A present required slot contributes evidence. A missing required slot subtracts evidence but does not erase an otherwise recognizable intent; the returned `COMPLETE` field reports whether all required arguments were found.

## Parse contract

`parse()` returns an ooRexx `Directory` with:

- `SCHEMA = symbolic.nlp.parse/0.2`
- `STATUS = MATCHED | AMBIGUOUS | UNKNOWN`
- `INTENT`
- `SCORE` and `MARGIN`
- `POLARITY = POSITIVE | NEGATED`
- `COMPLETE = 0 | 1`
- `SLOTS`
- `MISSING_SLOTS`
- `TOKENS`
- `CANDIDATES`
- `EVIDENCE`
- `SEMANTIC`
- `LOGICAL_FORM`

`SEMANTIC` uses schema `symbolic.nlp.semantic/0.1` and contains:

- `ACTION` node;
- `OBJECT` node;
- `ARGUMENTS`;
- `RELATIONS` (`PREDICATE_OBJECT`, `ARGUMENT`, `NEGATION`);
- `FORM`.

The logical form is an inspectable diagnostic representation, **not executable source code**.

## Deterministic evidence calculation

Core lexical evidence remains deliberately simple:

| Evidence | Score |
|---|---:|
| exact registered verb | +50 |
| unique-Soundex verb repair | +34 |
| exact registered noun | +35 |
| unique-Soundex noun repair | +22 |
| exact multiword phrase | +15 |
| verb before noun | +10 |
| present required slot marker/value | +12 |
| present optional slot marker/value | +6 |
| missing required slot | -12 |

Scores are evidence, not probabilities. Registration priority only breaks equal scores; it is not added to the evidence score.

The default acceptance threshold is 60 and the top-two ambiguity margin is 12.

## Boundary with COG

The intended boundary is:

```text
COG command/recipe ownership
        |
        +-- verb concepts
        +-- noun concepts
        +-- fixed discriminating phrases
        +-- argument grammar
        v
SymbolicNLPParser
        |
        +-- intent candidates
        +-- evidence scores
        +-- polarity
        +-- slots
        +-- semantic form
        v
COG plan/context/parameter accounting
        v
freeze / acceptance / governance / execution
```

This parser does not replace COG's context locking, frozen plans, parameter accounting or execution evidence. It provides a richer deterministic front end than whole-sentence regular expressions.

## Qualification

Tests are designed for ooRexx 5.3 and include:

- complete dev1 compatibility regression;
- reusable concept registration;
- quoted multiword arguments;
- `FROM ... TO ...` argument attachment;
- required-slot discrimination between related intents;
- missing-slot completeness reporting;
- scoped negation with skipped punctuation tokens;
- conservative Soundex repair preserving canonical concepts;
- semantic graph/logical-form generation.

## Files

- `src/SymbolicNLP.cls` — standalone parser class.
- `tests/test_dev1_regression.rex` — compatibility qualification.
- `tests/test_semantic_dev2.rex` — dev2 semantic qualification.
- `examples/cog_semantic_demo.rex` — COG-shaped registration example.
- `docs/DESIGN.md` — architecture and invariants.
- `docs/COG_SEMANTIC_REGISTRATION.md` — proposed registration seam.

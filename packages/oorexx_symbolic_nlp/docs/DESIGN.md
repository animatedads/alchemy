# Design: deterministic symbolic command semantics

## Purpose

The parser answers one narrow question:

> Given a vocabulary and argument grammar registered by command owners, which registered meaning is supported by an utterance, by how much evidence, with what polarity and arguments?

It does not decide whether the action is permitted and never executes the action.

## Why concepts are separate from intents

A tool often owns several commands that share vocabulary. Treating every intent as a private bag of synonyms duplicates semantic knowledge and makes collisions difficult to inspect.

Dev2 therefore introduces reusable concepts:

```text
CREATE: VERB -> CREATE | MAKE | DEFINE
CLASS : NOUN -> CLASS | TYPE
FILE  : NOUN -> FILE | DOCUMENT
```

An intent binds concepts into one command meaning:

```text
OOREXX_CREATE_CLASS := CREATE + CLASS
COPY_FILE           := COPY + FILE
```

The concept ID becomes the canonical action/object identity in the semantic form even if the surface word is a synonym or a conservative Soundex repair.

## Pipeline

1. **Concept registration** — command owners define canonical verbs/nouns and aliases.
2. **Intent registration** — commands compose those concepts plus optional discriminating phrases.
3. **Argument grammar** — slots declare markers, capture mode, requirement and optional stop markers.
4. **Word examination** — position-preserving tokens are normalized and matched exactly or by unique Soundex bucket.
5. **Candidate construction** — every intent receives deterministic evidence.
6. **Structural evidence** — verb/object order, exact phrases and argument markers affect score.
7. **Polarity** — negators immediately before the selected command verb are recorded independently.
8. **Slot binding** — `NEXT`, `REST` and `PHRASE` rules attach values.
9. **Decision** — threshold and top-two margin yield `MATCHED`, `AMBIGUOUS` or `UNKNOWN`.
10. **Semantic projection** — canonical action, object, argument and negation relations are returned.

## Important invariants

### Intent is not authority

`do not create a class` can strongly identify the `CREATE_CLASS` meaning while carrying `NEGATED` polarity. No downstream component may infer execution authority merely because an intent is recognized.

### Missing data is not the same as unknown intent

`create a class` can identify the create-class intent while lacking the required `CLASS_NAME`. The parser therefore separates:

- `STATUS`: confidence/ambiguity of intent selection;
- `COMPLETE`: whether required argument slots were bound.

### Ambiguity remains visible

Priority does not inflate score. It only provides deterministic ordering when evidence scores are equal. A close second candidate remains visible through the margin and can produce `AMBIGUOUS`.

### Soundex is conservative

Soundex repair is accepted only when one registered lexeme occupies the bucket. This avoids quietly mapping one typo to an arbitrary member of an ambiguous phonetic family.

### Negation uses token index, not raw word position

Punctuation-only words can disappear during examination. Dev2 therefore keeps both source `POSITION` and compact token `INDEX`; syntactic windows use `INDEX`, preventing skipped punctuation from corrupting negation scope.

## Slot capture modes

### NEXT

One token following the marker.

```text
called Widget
       ^^^^^^
```

### REST

Everything after the marker.

```text
in src/library/generated
   ^^^^^^^^^^^^^^^^^^^^^
```

### PHRASE

If the value begins with a quote, capture through its closing quote. Otherwise capture until a registered stop marker or end of utterance.

```text
called "Invoice Line" with no methods
       ^^^^^^^^^^^^^^

from source.txt to backup/source.txt
     ^^^^^^^^^^
```

The grammar remains deterministic because stop markers come from the command owner.

## Semantic projection

For:

```text
copy file from source.txt to backup/source.txt
```

the structural meaning is equivalent to:

```text
INTENT: COPY_FILE
POLARITY: POSITIVE
ACTION: COPY
OBJECT: FILE
ARGUMENT SOURCE: source.txt
ARGUMENT DESTINATION: backup/source.txt
RELATION: PREDICATE_OBJECT(COPY, FILE)
RELATION: ARGUMENT(SOURCE, source.txt)
RELATION: ARGUMENT(DESTINATION, backup/source.txt)
```

The compact `LOGICAL_FORM` is intended for logs, tests and human inspection. The Directory/Array graph remains the authoritative structured representation.

## What this deliberately does not attempt yet

- statistical POS tagging;
- probabilistic confidence;
- neural embeddings;
- unrestricted natural-language understanding;
- automatic execution;
- unrestricted stemming that could collapse command identities;
- CCG/DRT/FOL completeness;
- cross-clause planning.

Those are separable concerns. The useful target here is a small symbolic front end whose decisions can be inspected and reproduced.

## Natural next extensions

1. context/domain constraints on intent registration;
2. conjunction/clause splitting for multi-command requests;
3. explicit modifier concepts (`recursive`, `safe`, `current`);
4. typed slots (`PATH`, `INTEGER`, `IDENTIFIER`, `TEXT`);
5. declarative registration import/export once the COG-side schema is frozen;
6. optional Librarian lexical provider adapter while keeping this class standalone.

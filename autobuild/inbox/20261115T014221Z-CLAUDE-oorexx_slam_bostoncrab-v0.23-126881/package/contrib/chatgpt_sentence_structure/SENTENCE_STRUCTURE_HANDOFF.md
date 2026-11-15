# Reader v0.3.2 — sentence-structure handoff (4 Nov 2026)

Architecture: existing Alchemy ooRexx Reader. This is a conservative additive front-end, **not** a replacement parser.

## What was verified
- Supplied Ubuntu debug ooRexx package runs and identifies itself as 5.3.0 r13196.
- `test_sentence_structure.rex` passes its 5 assertions with this interpreter.
- `audit_structure.rex story3/story.txt story3/sentence_audit.tsv` emits 22 sentence records.
- `compile.rex .` compiled 548 concepts, and the current primary `read_story.rex .` read 49 props, 25 entities, 8 findings, 0 unread on the root `story.txt`.
- **Do not trust the current scramble_test.rex PASS**: it hardcodes `/home/claude/reader`, continues after failed commands, and can compare two empty outputs as identical. It did exactly that on this machine. Fix and rerun it before making claims of semantic isolation.

## Findings and integration plan
1. Never discard punctuation/case before structural capture. Store raw text, source offsets and sentence kind; tokenize a separate normalised copy for lexicon lookup. `sentence_structure.cls` is a safe first step. It makes **no semantic assertions**.
2. Preserve noun-phrase attachment: in `Barnaby was a hound with long ears`, `with long ears` attaches to `hound`, not automatically to the main event. In `Pip saw the dog with binoculars`, retain competing attachments until context disambiguates.
3. Introduce clause **nodes**, not only a list of verb cues: conjunction `and` can join nouns, verbs or independent clauses. Mark `if` as condition; `because` as reason; `when` as time; `that` as complement/relative depending on attachment. A cue alone is never proof of a clause boundary.
4. Fix copula vs auxiliary ambiguity: `Pip was happy` is predication; `Pip was holding an acorn` is progressive auxiliary + verb. `Pip was a squirrel` is a noun complement. Keep morphosyntax separate from WordNet senses.
5. Establish event scopes: narration FACT, spoken ASSERTION(source=speaker), hypothetical CONDITIONAL, and QUESTION. Do not put a quoted allegation straight into world-state FACTS.
6. Pronouns refer to discourse mentions, not nearest matching noun only. Score recency, subject continuity, plurality, animacy, speaker, and explicitly mark ambiguous. Preserve unresolved text with offsets; never force a guessed referent.
7. On every consumed parse span, maintain an exact token coverage mask. Reject a parse as COMPLETE if any non-punctuation token is left outside an attached node; report a reason code. Unread != factual failure.
8. Emit typed records (sentence/clause/event/entity/relation) with provenance document ID, sentence offsets, source and confidence/evidence kind. Stable concept IDs remain opaque and the gloss-scramble invariant applies.
9. For Simple English Wikipedia: process licensing and attribution; articles in small indexed batches; headings, lists, captions and tables separately; source-date/provenance per claim; disambiguation and redirects as metadata. Do not treat claims as universally true because they appear in an article.
10. Validation gates: boundaries -> complete-span grammar -> role assignment -> coreference -> reasoning -> realisation; measure separately on Pip/Barnaby stories and the supplied story3 before a Wiki import.

## Execute
From this directory (with the normal project's ooRexx and runtime paths configured):
```
rexx test_sentence_structure.rex
rexx audit_structure.rex story3/story.txt story3/sentence_audit.tsv
```

## Next implementation priorities for Claude
- Wire `SentenceStructure~split` into `Reader~readFile` as an optional `structure` mode, keeping legacy mode to compare graphs.
- Avoid `Reader~tokens` lowering text until after span/case annotation.
- Add clause-node graph and strict consumed-token coverage in `Reader~parseClause` and `parseVerbPhrase`.
- Unit cases: `Pip ran and jumped`; `Pip and Barnaby ran`; `If Pip runs, Barnaby follows`; `Pip said, "The nuts are gone"`; `He saw her duck`; `Pip was holding a nut`; `The dog saw Pip with binoculars`.
- Report metrics: % sentence boundaries correct; % accepted complete spans; % clauses linked correctly; % referents explicit/ambiguous/unresolved; false facts asserted. Never equate 0 unread with correctness.

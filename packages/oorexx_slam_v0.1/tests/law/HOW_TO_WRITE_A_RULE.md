# How to write a rule file (for the small model: Luna, Haiku)

Architecture: Tom Dyer. Written by Claude (Opus 5.5), 2026-10-29.

You turn ONE section of UK legislation into ONE rule file. SLAM checks your file. If any check fails, the file is refused, and nothing you wrote is used. Copy the layout of `cma1990_s1.md` exactly.

## Input you are given

1. The section's text for ONE extent: England and Wales (`E.W.`) or Scotland (`S.`). It comes from the legislation.gov.uk XML (`tests/law/source/`, listed in `MANIFEST_LEGISLATION.md`). Do not use any other copy, and do not use your memory of the law. If the text is the same in both extents, one file can say `extent: E.W. S.`.
2. SLAM's word list (`corpus/circular_corpus_v2.csv`).
3. The list of kinds (`tests/law/VOCABULARY.md`). Every kind you write must be in it. Do not make up a new name for a thing that is already there.

## Steps

1. Start the file with `# a rule` and a code block holding these lines:
   - `rule: <act>.<section>`, for example `rule: cma1990.s1`
   - `extent: E.W.` or `extent: S.`
   - `section: <number>`, for example `section: 1` or `section: 3ZA`
   - `written by: <your model name>, <date>`
   - `source: <act name>, section <number>, <the legislation.gov.uk URL>`
2. Write the definitions. Each one goes on its own line as `word: definition`. Use only words from SLAM's word list, or words you have already defined above that line. Define a word BEFORE its first use. A plural needs its own line (`elements: more than one element`).
3. Write `it is about an event of kind:` and a code block holding the kinds of EVENT the offence can be about (for example `CREDENTIAL_USED`). Take them from `VOCABULARY.md`.
4. Write `the law, as code:` and then a code block holding the subsection, copied character for character from the input. Change nothing.
5. For EACH lettered paragraph, (a), (b), (c) and so on, write one element. A paragraph that holds two conditions that must BOTH be true is two elements: "the person does any unauthorised act" is "the person did it" (PERSON_ACT) and "it was unauthorised" (AUTHORITY). Paragraphs joined by "or" are ONE element with one quote for each paragraph:
   - `element <n>:` (n is 1, 2, 3 …)
   - a code block holding the exact words of the paragraph that the element comes from. Copy them; do not paraphrase. For an "or", one code block for each paragraph, one after the other.
   - one sentence in SLAM's words saying what must be true.
   - `it takes evidence of:` and a code block holding the kinds from `VOCABULARY.md`, for example `PERSON_ACT`, `INTENT_ACCESS`, `KNOWLEDGE_UNAUTHORISED`, `AUTHORITY`. Any ONE kind in the block is enough for the element, so write two kinds only when the law says "or" ("intends ... or is reckless": `INTENT_DAMAGE RECKLESSNESS_DAMAGE`).
   - When the element is itself an offence ("he commits an offence under section 1"), write `it is the offence:` and a code block holding that rule's id (`cma1990.s1`), instead of `it takes evidence of:`.
6. End with one line: `rule: when element 1, element 2, … and element <last> are true, the offence is true.` Name every element.

## Do not

- Do not leave out a paragraph. Every one of (a), (b), (c) … needs an element.
- Do not write a quote that is not in the section word for word ("ought to know" is not "knows").
- Do not use a word that SLAM does not know and that you did not define. For example, "reckless" and "whether" must be defined before you use them.
- Do not add words from a different extent. Words marked as inserted for Scotland are not England and Wales's law.
- Do not decide anything about a case. You only write the rule.
- Do not use a kind that is not in `VOCABULARY.md`, and do not make a new name for a thing that has one. If a thing has no kind, stop and ask: a new kind needs a definition, and a new version of the list.
- Do not name a kind after its conclusion. A kind of event says what happened (`REPRESENTATION_MADE`), never what the evidence has to show (`FALSE_STATEMENT`). The list refuses an event whose definition uses a word of a finding (knows, intends, unauthorised, false, dishonest, forces, reckless, offence).

## How SLAM checks your file

```
rexx bin/slam.rex corpus check.db corpus/circular_corpus_v2.csv
rexx bin/slam.rex read check.db tests/law/<your file>.md
```

The last line must be: `i know each word here. i can read all of it.` Then `tests/test_law.rex` and `tests/test_screen.rex` check the rest (gate 6: every kind is in the list): the text is the official text for the extent, each quote is word for word, every paragraph is covered, and the rule line names every element.

## Guidance files (CPS and similar)

These follow the same layout as `cps_cma.md`. Each `note <n>:` has:
- a code block quoting the guidance word for word;
- one sentence in SLAM's words;
- `for element <n>, it takes evidence of:` (the element takes ONLY these kinds) or `for element <n>, it can not take evidence of:` (these kinds are refused);
- a code block of evidence kinds.

Guidance only narrows which evidence counts. It never adds an element.

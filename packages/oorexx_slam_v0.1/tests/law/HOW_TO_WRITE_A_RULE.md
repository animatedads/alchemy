# How to write a rule file (for the small model: Luna, Haiku)

Architecture: Tom Dyer. Written by Claude (Opus 5.5), 2026-10-29.

You turn ONE section of UK legislation into ONE rule file. SLAM checks your file. If any check fails, the file is refused, and nothing you wrote is used. Copy the layout of `cma1990_s1.md` exactly.

## Input you are given

1. The section's text for ONE extent: England and Wales (`E.W.`) or Scotland (`S.`). It comes from the legislation.gov.uk XML. Do not use any other copy, and do not use your memory of the law.
2. SLAM's word list (`corpus/circular_corpus_v2.csv`).

## Steps

1. Start the file with `# a rule` and a code block holding these lines:
   - `rule: <act>.<section>`, for example `rule: cma1990.s1`
   - `extent: E.W.` or `extent: S.`
   - `section: <number>`, for example `section: 1` or `section: 3ZA`
   - `written by: <your model name>, <date>`
   - `source: <act name>, section <number>, <the legislation.gov.uk URL>`
2. Write the definitions. Each one goes on its own line as `word: definition`. Use only words from SLAM's word list, or words you have already defined above that line. Define a word BEFORE its first use. A plural needs its own line (`elements: more than one element`).
3. Write `the law, as code:` and then a code block holding the subsection, copied character for character from the input. Change nothing.
4. For EACH lettered paragraph, (a), (b), (c) and so on, write one element. Split a paragraph into two elements only if it holds two separate conditions:
   - `element <n>:` (n is 1, 2, 3 …)
   - a code block holding the exact words of the paragraph that the element comes from. Copy them; do not paraphrase.
   - one sentence in SLAM's words saying what must be true.
   - `it takes evidence of:` and a code block holding one or more evidence kinds in capitals, for example `PERSON_ACT`, `INTENT`, `KNOWLEDGE`, `AUTHORITY`, `RECKLESSNESS`.
5. End with one line: `rule: when element 1, element 2, … and element <last> are true, the offence is true.` Name every element.

## Do not

- Do not leave out a paragraph. Every one of (a), (b), (c) … needs an element.
- Do not write a quote that is not in the section word for word ("ought to know" is not "knows").
- Do not use a word that SLAM does not know and that you did not define. For example, "reckless" and "whether" must be defined before you use them.
- Do not add words from a different extent. Words marked as inserted for Scotland are not England and Wales's law.
- Do not decide anything about a case. You only write the rule.

## How SLAM checks your file

```
rexx bin/slam.rex corpus check.db corpus/circular_corpus_v2.csv
rexx bin/slam.rex read check.db tests/law/<your file>.md
```

The last line must be: `i know each word here. i can read all of it.` Then `tests/test_law.rex` checks the rest: the text is the official text for the extent, each quote is word for word, every paragraph is covered, and the rule line names every element.

## Guidance files (CPS and similar)

These follow the same layout as `cps_cma.md`. Each `note <n>:` has:
- a code block quoting the guidance word for word;
- one sentence in SLAM's words;
- `for element <n>, it takes evidence of:` (the element takes ONLY these kinds) or `for element <n>, it can not take evidence of:` (these kinds are refused);
- a code block of evidence kinds.

Guidance only narrows which evidence counts. It never adds an element.

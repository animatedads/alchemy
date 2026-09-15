# Bash Best Practices Gopher sphere v0.2

LLM-focused bash best practice, evenly covering pure-bash *technique* and the
fail-closed *doctrine* bashqueues hard-wires. Every lesson is grounded in a real
bashqueues file (queuebash.sh ~0.18.139, bin/queue-*, providers, docs/*_CONTRACT.md)
and then generalized as best practice for authoring LLMs.

It adds only:
- `packs/bash-best-practices/` (manifest, access policy, articles, corpus, rules)
- `profiles/bash-best-practices.json`
- `tests/run_bash_best_practices_sphere.sh`
- qualification/manifest files

It does not replace `engine/gopher.py`, and it layers `packs/core + packs/bash-best-practices`.

Engine reality (why the posture is what it is): the engine has no built-in bash-rule
evaluator (`rules check` supports oorexx/python only). The five rule documents here
(`language: bash`) are therefore reference guidance rendered via `rules show`. Each
carries an `assess` object separating detection certainty from whether the pattern is
actually a violation from whether an automatic rewrite is safe, because a single
`fixability` value hides where judgement is required (see article
`ops.rule-classification`). This keeps the rules honest and avoids weak or over-confident
auto-fixes.

Start with:

    ./gopher --profile bash-best-practices context bash-best-practices
    ./gopher --profile bash-best-practices open ops.rule-classification
    ./gopher --profile bash-best-practices open bash-best-practices.data.output-is-data-never-executed
    ./gopher --profile bash-best-practices search 'never executable' --sphere bash-best-practices
    ./gopher --profile bash-best-practices lookup topic=json-emit --sphere bash-best-practices
    ./gopher --profile bash-best-practices rules show BASH.QUOTING.UNQUOTED_EXPANSION --language bash

Qualification (data-only, no ooRexx runtime required):

    ./tests/run_bash_best_practices_sphere.sh

v0.2 change: added the rule `assess` model and the `ops.rule-classification` article;
re-published the quoting rule as contextual/MANUAL (no unsafe AUTOMATIC).

# Python Best Practices Gopher sphere v0.1

LLM-focused, portable Python best-practice guidance: the antidote to the sloppy
patterns that are over-represented in LLM training corpora.

It adds only:
- `packs/python-best-practices/` (sphere manifest, access policy, articles, corpus, rules)
- `profiles/python-best-practices.json`
- `examples/python-method/*.py.frag` (one-complete-method splices for `source.python.method.edit`)
- `tests/run_python_best_practices_sphere.sh`
- qualification/manifest files

It does not replace `engine/gopher.py`, and it layers `packs/core + packs/python-best-practices`.

Engine reality (why the posture is what it is):
- `rules check` executes exactly four statically-detectable Python breaches
  (syntax, duplicate method, wildcard import, bare except). A sphere cannot add
  executed breaches without editing the engine.
- Therefore the python `language-rule` documents in this sphere are reference
  guidance shown via `rules show`, each with a real deterministic trigger and a
  concrete correction. Only genuinely deterministic triggers are given the rule
  form; everything needing intent or call semantics is an article.
- Example splices under `examples/python-method/` are each one complete method,
  the exact `replacement_path` shape `source.python.method.edit` consumes and
  validates before committing an AST-scoped change.

Start with:

    ./gopher --profile python-best-practices context python-best-practices
    ./gopher --profile python-best-practices open python-best-practices.defaults.no-mutable-default-argument
    ./gopher --profile python-best-practices search 'mutable default' --sphere python-best-practices
    ./gopher --profile python-best-practices lookup topic=none-check --sphere python-best-practices
    ./gopher --profile python-best-practices rules show PYTHON.DEFAULT_MUTABLE --language python

To inspect one example splice intended for `source.python.method.edit`:

    cat <activated-archive>/examples/python-method/collect_names_no_mutable_default.py.frag

Qualification (data-only, no ooRexx runtime required):

    ./tests/run_python_best_practices_sphere.sh

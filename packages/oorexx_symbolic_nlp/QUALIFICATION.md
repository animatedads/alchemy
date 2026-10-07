# Qualification — ooRexx Symbolic NLP v0.1-dev2

Qualified on the supplied runtime:

`Open Object Rexx Version 5.3.0 r13196 - Internal Test Version`

## Runtime suites

- `tests/test_dev1_regression.rex`: **11 PASS lines**, exit 0.
- `tests/test_semantic_dev2.rex`: **32 PASS lines**, exit 0.
- `examples/cog_semantic_demo.rex`: executes successfully and distinguishes current-directory, path-directory, copy-file and extract-archive meanings.

The dev1 suite is retained unchanged apart from its filename, so dev2 is tested against the original intent/negation/ambiguity/typo behaviours as well as the new semantic API.

## Standards enforcement

The final archive is checked with `oorexx_standards_enforcer.py`.

Expected non-failing warnings are the tool's private-method Message-activity caution and loop-invariance heuristic. Internal private methods are synchronously invoked by `self`; no asynchronous Message boundary is used by this component.

No `&`/`|` short-circuit hazards are accepted in the parser implementation.

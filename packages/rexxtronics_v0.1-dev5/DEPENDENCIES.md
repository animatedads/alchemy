# Dependencies

## ooRexx Units

Pinned qualification dependency: `oorexx_units_v0.1-dev2`.

The tree under `deps/oorexx_units_v0.1-dev2/` is an unmodified snapshot of the user-supplied shared Units package. It is present solely for reproducible qualification and must not become a Rexx-tronics-private Units fork.

Runtime/test lookup is controlled by `REXX_PATH`; `run_tests.sh` uses the bundled snapshot unless `REXXTRONICS_UNITS_ROOT` points at another compatible Units tree.

Rexx-tronics relies on Units for:

- dimensional algebra and semantic families;
- canonical SI values and unit conversion;
- source/display unit identity;
- 50-digit arithmetic boundaries;
- parseable engineering-unit text and UTF-8 aliases;
- stable quantity metadata (`oorexx.units.quantity/0.1`).

Physics is expected to consume the same shared Units authority, allowing Rexx-tronics/Physics interchange without a second conversion system.

## ooRexx

Qualified against Open Object Rexx 5.3.0 r13196 Internal Test Version from the supplied debug build.

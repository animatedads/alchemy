# Alchemy Autobuild Environment Contract

For ooRexx packages, do not rely on the service/login shell to find classes.
Declare the environment needed by each test.

Use `environment.set` for named package roots such as `REPUTATION_EFFECT_ROOT`.
Use `environment.rexx_path` for Rexx source/class lookup. Prefer `mode: replace` for acceptance probes so stale external paths cannot win search order.
Use `require_dirs` for package-root exports and `require_entries: true` for REXX_PATH entries.

A package-level environment is the common base. A `tests[].environment` overlay may replace or extend it for one script. This is intentional: two tests in the same package may require different dependency surfaces.

The result for every test records effective `PATH`, `REXX_PATH`, the Alchemy package/repository roots, and every variable named in `report`, `require`, or `require_dirs`.

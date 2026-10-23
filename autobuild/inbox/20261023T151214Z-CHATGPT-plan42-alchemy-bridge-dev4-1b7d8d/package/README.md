# Plan42 integration into Alchemy — v0.1-dev4 candidate

The source is extracted from the accepted Alchemy 65 / Plan42 dev4 candidate. The
package contains Plan42 compiler entry points, ooRexx service facade, read-only
RX2CPP native-plan and object-model inventory import, manifest and regression tests.

**Authority:** This is a development candidate. It is NOT the full modern Alchemy
source estate; its `runner.rex` belongs to the older framework65 baseline. No
live ooRexx/native/C++ execution, registry publication or class replacement
was qualified by this package.

`plan42.integration.json` is the Plan42 service descriptor, distinct from the
root `integration.json` which directs Alchemy Autobuild. The `rx2cpp.upstream.pin`
file is historical provenance; do not mistake it for current GitHub `main`.

## Qualification

Run `python3 -m unittest discover -s tests -p 'test_plan42*.py' -v`.
A test run without `rexx` only qualifies the Python bridge and mock receipt/
inventory contracts. Native RX2CPP requires a pinned checkout and differential
run against ooRexx / GCC / Clang before promotion.

See `docs/PLAN42_RX2CPP_OBJECT_MODEL_DEV4.md` and `provenance.json`.

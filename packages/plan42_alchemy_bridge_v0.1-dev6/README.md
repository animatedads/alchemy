# Plan42–Alchemy bridge 0.1-dev6

Dev6 adds path-component symlink protection for generated ooRexx sources and compilation receipts, and full visible RX2CPP compiler-tree cleanliness checking before any proposed native build arguments. No execution, registry publication, or upstream repin occurs. See [dev6 documentation](docs/PLAN42_RX2CPP_DEV6_PATH_AND_TREE_INTEGRITY.md).

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

## Dev5 (2026-10-27) — RX2CPP pinned working-tree verification

`native-plan` now verifies all seven declared RX2CPP interface Git blobs against on-disk sources, not simply `HEAD`. See [dev5 checkout integrity](docs/PLAN42_RX2CPP_DEV5_CHECKOUT_INTEGRITY.md). The observed newer main `e3d8d00` is a review candidate; the 2026-10-15 pin remains unchanged. No native compilation or automated publication occurs.

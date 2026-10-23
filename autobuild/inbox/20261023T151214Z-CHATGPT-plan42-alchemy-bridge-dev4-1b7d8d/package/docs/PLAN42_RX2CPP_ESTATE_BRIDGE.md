# Plan42 to RX2CPP: ooRexx-centred estate integration (dev3)

**Status:** additive candidate, not published, not executable acceptance. Based on
`animatedads/oorexx` commit `9047f0e13c8cd67acf4258bd69cf78ea946944ac`
(2026-10-15), `oorexx2cpp/VERSION` = `0.30.18`.

## Architecture and authority

Alchemy application semantics continue to live in **ordinary ooRexx classes,
methods and intention/service objects**. Plan42 is the portability, diagnostic,
semantic transformation and generated-source service; it is not a second class
registry. The existing coding-intention and workbench packages own development
requests and preflight; Semantic Source Store owns accepted source revisions;
Runtime Registry owns published generations; Connect Selector selects DIRECT/RPC/
QUEUE when a service actually needs transport. None is implicitly changed here.

RX2CPP is the downstream **ooRexx-written** compiler: it can lower qualified
Rexx source to standalone C++17 programs or interpreter-loadable native package
libraries. It is **not** an implementation of the Plan42 generic `cpp` target.
Native outputs must remain subject to interpreter parity and publication policy.

    Alchemy .cls/.rex code  -- governed source and intentions
             |
          Plan42 IR  -- semantic audit / target compatibility
             |
       Plan42 ooRexx emitter -- generated/plan42/*.rex
             |
       native-plan (read-only) -- hash + optional receipt + revision pin
             |
    RX2CPP interpreter-owned inspection and scoped rule engine
             |                        (future separately authorised invocation)
       [standalone C++17] OR [native library .so]
             |
       differential / load / rollback tests
             |
       Semantic Source Store + Runtime Registry publication authority

## RX2CPP upstream facts and boundaries

- `core/RxWhenDealingWith.cls`: lexically identified code-unit and activation
  scope. Does not itself instantiate a live interpreter activation.
- `core/RxRexxRuleSelection.cls`: one rule-selection algorithm but **not yet** a
  single executable rule set for both standalone and native backends.
- `inspector/inspect.rex`: interpreter-authoritative Package/Class/Method/Routine
  source and visibility inventory; reports compiled source/metadata **not a full
  statement AST**. It rewrites a *temporary inspection copy* and refuses
  `::REQUIRES` until imports can be isolated. Untrusted source is not sandboxed.
- Native `.so` package backend and standalone executable backend are different
  compilation modes. Neither is silently selected by the other.
- The reference `crypto.cls` is **not** qualified as a compiled native library;
  upstream v0.30.15 recorded the next X2D BIF boundary. Scalar-only native
  routine argument paths still differ from general object-valued ooRexx calls.
- Upstream v0.30.18 focuses NUMERIC parser/rule selection; its document
  explicitly states full current-main regression was not rerun.

Source references:

- <https://github.com/animatedads/oorexx/blob/main/oorexx2cpp/UNIFIED_STATEMENTS_V0318.md>
- <https://github.com/animatedads/oorexx/blob/main/oorexx2cpp/SCOPE_ENGINE_V0316.md>
- <https://github.com/animatedads/oorexx/blob/main/oorexx2cpp/OBJECT_INSPECTION_V0317.md>
- <https://github.com/animatedads/oorexx/blob/main/oorexx2cpp/native/build.sh>

## Delivered source

- `tools/plan42_rx2cpp_plan.py`: **pure read-only** build-plan and guard tool.
  It requires generated ooRexx source inside `generated/plan42` and enforces
  exact SHA-256 when provided, rejects symlinks and mismatched mode extensions,
  optionally verifies a Plan42 compiler receipt and exact RX2CPP Git checkout
  pin. Its normal return is `PROPOSED_ONLY` or `REVIEW_REQUIRED`.
- `tools/plan42_bridge.py native-plan`: Alchemy compiler bridge operation.
- `plan42/AlchemyPlan42Service.cls~nativePlan(...)`: optional ooRexx service
  entrypoint using the existing isolated `.ExternalCall` boundary.
- `plan42/plan42.integration.json`, `estate/plan42.estate.candidate.json`:
  documentation-only intention/estate integration. Not an authoritative Runtime
  Registry publication.

## Usage

First generate ooRexx with the existing Plan42 service. Supply the resulting
compiler JSON receipt **saved separately** to use the optional digest guard.

```sh
python3 tools/plan42_bridge.py compile \
  --spec tools/class_greeter.plan42.json --target oorexx --engine python \
  --output generated/plan42/class_greeter.rex > reports/class_greeter.compile.json

python3 tools/plan42_bridge.py native-plan \
  --source generated/plan42/class_greeter.rex --mode standalone \
  --receipt reports/class_greeter.compile.json
```

**Important:** The receipt must live under the Alchemy workspace to be accepted.
The exact Plan42 output hash and native compatibility status must match. A
compatible Plan42 result does **not** assert RX2CPP supports every construct.

With an **exact pinned** local Git checkout of RX2CPP:

```sh
python3 tools/plan42_bridge.py native-plan \
  --source generated/plan42/class_greeter.rex --mode standalone \
  --compiler-root /some/checkout/oorexx \
  --receipt reports/class_greeter.compile.json
```

A valid checkout and native-compatible receipt produce an *argv proposal* for
`oorexx2cpp/build.sh` but do not invoke it. A native `.cls` source instead uses
`--mode native-package` and `oorexx2cpp/native/build.sh` with its three-argument
package ABI. Both modes retain `executed=false`, `published=false`,
`replaced=false`. A package `.cls` cannot be silently inferred from Plan42's
`.rex` output; that needs an explicit packaging stage and separate qualification.

### Safety qualification gates before any real build

1. Resolve the accepted Alchemy source revision from Semantic Source Store;
   do not replace it with a local hash.
2. Read Plan42's compatibility report and refuse degraded/unresolved source
   for strict native qualification, even when embedded roundtrip is exact.
3. Verify RX2CPP checkout SHA, compiler mode and dependencies (`rexx`, C++17,
   headers and libraries); run interpreter/native differential tests.
4. Run native `::REQUIRES`, class visibility, argument identity, numeric scope,
   prologue/load-order, and failed-compile rollback tests specific to the unit.
5. Obtain separately governed authorisation before publishing a `.so`, changing
   a Runtime Registry generation, or invoking `CODELET:DEFINE` / live upgrade.

This dev3 increment does none of steps 1, 3-5; it supplies a guarded plan to the
existing governance surfaces rather than manufacturing their authority.

## Validation scope

- Python syntax and eight focused planner/bridge boundary tests can run without
  `rexx` or a C++ compile.
- The host's direct live ooRexx `nativePlan` method has **not** been exercised;
  no binary or native package is produced.
- The GitHub upstream sources were inspected read-only and are not copied,
  modified, or published by this drop.

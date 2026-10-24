# cREXX Alchemy qualification

Status: pending runtime execution against pinned CREXX.

## Fixtures (dev3 archive)
- alchemytest.crexx: typed box, identity, alias-visible state, idempotent close, nested A -> RXPA -> B -> RXPA -> C sentinels.
- alchemytest_signal.crexx: division_by_zero propagation through CALLMETHOD, outer object survives.
- alchemytest_lifetime.crexx: payload copy and replacement smoke.

## Run
Set CREXX_ROOT to the exact checkout at 4468c7d75925cc158a568392f4abe97a59156df6 and CREXX_BUILD to its matching build tree, then run scripts/qualify-crexx.sh from the dev3 delivery.

## Acceptance requirements
1. Compile provider with pinned crexxpa.h, no ABI shims.
2. Compile, assemble and link each fixture.
3. Run both VM variants with optimized and unoptimized images.
4. Check copy/finalize balance and factory failure cleanup.
5. Check repeated nested entry, negative ordinary results, and catchable signals.
6. Record compiler, VM, platform, exact revision, commands, exit codes and logs.

Source-contract checks alone are not a pass. No runtime qualification claimed.

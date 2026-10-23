# .NET Alchemy — upstream bridge adoption (2026-10-23)

## Decision
Adopt Josep Maria Blasco's **ooRexx/.NET** as the upstream implementation for CLR ↔ ooRexx interoperability. Do not promote the experimental Alchemy native bridge into a competing production stack.

Upstream: https://github.com/JosepMariaBlasco/oorexxnet
Observed main commit: 1a5db49af0232749c40bbba19839048a5284730c
License reported by upstream repository: Apache-2.0.
Upstream README status: **prototype**; it reports >500 automated tests on Linux, Windows and macOS, and .NET 8/10 support. Those are upstream claims, not local Alchemy qualification.

## Division of authority
- Upstream owns CLR host/bootstrap, identity round trips, reflection and overload binding, generic types, properties, events, lifetime, .NET → Rexx host API and CLR.CLS compatibility.
- Alchemy owns its *integration* with AlchemyObject/ForeignObject, semantic cooperative method interposition, Inspector/Clouseau, Logging, governance and cross-runtime qualification.
- Keep the experimental v0.2.15 source for differential probes and migration evidence, but no longer expand its independent native CLR runtime except to fix safety or migration tests.
- Never confuse upstream .NetObject with AlchemyDotNetObject or silently change public method/identity semantics.
- No forced replacement of upstream physical wrappers; observers must remain cooperative and non-owning.
- Preserve exact CLR Type, exceptions and object identity as CLR authority; preserve Rexx UNKNOWN and omission semantics separately.

## Migration gates
1. Pin upstream source/release and license; reproduce upstream tests on target Linux/.NET and ooRexx, then Android/Termux where possible.
2. Port existing v0.2.14/v0.2.15 identity, reentry, omission/NIL/EMPTY, type, exception, concurrency and Inspector probes to upstream's public APIs.
3. Implement an Alchemy adapter around Rexx.Net and net.cls rather than modifying upstream reflection internals.
4. Prove current CLR target is revealed after removing a Rexx override, single physical wrapper, cooperative Inspector+Logging and stable identity.
5. Package exact dependencies; qualify clean-machine install. No runtime PASS without execution.
6. Only then propose promotion to main and retire the independent native bridge.

## Library reconciliation
Library search for Josep Maria's .NET bridge found related portfolio/Alchemy reports but not a local authoritative ooRexx.NET source archive. GitHub is the source of truth for this upstream dependency.

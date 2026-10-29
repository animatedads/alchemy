# .NET Alchemy: upstream bridge adoption decision (2026-10-27)

## Decision
Use Josep Maria Blasco's Apache-2.0 ooRexx/.NET bridge as the preferred general-purpose CLR interoperability implementation, subject to local qualification. Do not extend the Alchemy experimental bridge into a competing generic implementation. Keep the accepted Alchemy v0.2.14 baseline unchanged; v0.2.15 remains experimental.

Upstream: https://github.com/JosepMariaBlasco/oorexxnet
Upstream reports .net/.NetObject projection, C# RexxInterpreter/RexxObject hosting, round-trip identity, properties, events, callbacks, CLR.CLS compatibility, Linux/macOS/Windows CI, .NET 8/10, and over 500 tests. Its own README calls the API a prototype, so production qualification is not yet established by this decision.

## Alchemy-specific extension responsibilities
1. Live CLR behaviour generation publication and immutable in-flight snapshot semantics.
2. Cooperative Inspector Clouseau / Logging / Rexx override observation without replacing the CLR's authoritative identity or stale CLR target.
3. AlchemyObject / AlchemyForeignObject projection compatibility, avoiding duplicate physical wrappers.
4. Explicit authority and lifetime policy for object handles, native callbacks, threading, and exceptions.
5. Android/Termux platform qualification (upstream's advertised CI is Linux/macOS/Windows, not Android).

## Migration/qualification gates
- Pin an immutable upstream commit/tag and verify Apache-2.0 licensing and complete dependency closure.
- Run upstream's official suites unmodified, record environment and actual results.
- Run Alchemy v0.2.14 baseline regression and v0.2.15 live generation / Inspector / override tests against an adapter, without claiming existing probes directly exercise upstream.
- Map .net/.NetObject and RexxInterpreter/RexxObject to Alchemy's foreign-object contracts; avoid transplanting bridge internals.
- Verify nil/omitted/empty, overloaded methods, object identity, System.Type, CLR exceptions, callbacks/reentry, concurrent mutation, lifetime and cross-thread release.
- Compare BSF4ooRexx CLR.CLS compatibility and installation/registry resolution; do not manually assemble runtime paths.
- Only promote after tested Linux and Android evidence; Windows/macOS as relevant.

## Missing work
- Implement the upstream-backed Alchemy adapter and retain native fallback only as a separately identified experiment.
- Add CI matrix and failure reports with pinned upstream revision.
- Close exact repaired Inspector v0.8.1 dependency closure and test coordinator compatibility.
- Register the sphere/component in the portfolio register and add release/rollback criteria.

## Sources
- Upstream README: https://github.com/JosepMariaBlasco/oorexxnet
- Rony G. Flatscher, .Net for ooRexx, 2016 symposium proceedings (published 2023): https://research.wu.ac.at/en/publications/net-for-oorexx-3/
- Manuel Raffel, ooRexx.NET thesis (2015): https://wi.wu-wien.ac.at/rgf/diplomarbeiten/BakkStuff/2015/20150810_Raffel-Manuel-ooRexx-Net-architecture.pdf

Status: architecture decision and migration backlog committed; no upstream runtime qualification asserted.

## Upstream revision observation (2026-10-29)
Pinned integration candidate: `JosepMariaBlasco/oorexxnet@bffd7ae127d559ad51e8128f9c9c27175ef4c35a` (observed upstream HEAD; integration must use this immutable SHA, not a moving branch).
Latest upstream change repairs propagation of Rexx conditions while encoding custom LogicalWrapper/NetRef/NetTyped/NetHandler values, including callback replies; upstream commit reports seven phase3 tests and one HostTests case. This is upstream-authored evidence only, not a locally reproduced PASS.

Additional mandatory adapter regression: an overridden VALUE, KIND or MAKESTRING raising a Rexx condition must abort argument serialization before invoking CLR code; the original Rexx condition must reach the caller, including on callback return. No synthetic 91.999 error or silent coercion to false. Verify the upstream fix under the pinned revision and document test output before adoption.

Do not apply the legacy v0.2.15 binder to upstream's member resolution: upstream owns generic CLR overload binding. Preserve Alchemy-specific generation/observer behavior as an adapter layer.

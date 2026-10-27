# ooRexx .NET Alchemy sphere v0.1

Authority: Alchemy extension and qualification of Josep Maria Blasco's upstream ooRexx/.NET bridge.
Rasen Falcon component lane: oorexx-dotnet-alchemy.
Git development branch: tmp-dotnet-alchemy-v0.2.15.
Accepted rollback baseline: packages/oorexx_dotnet_alchemy_v0.2.14.

## Sphere decision
The upstream Apache-2.0 implementation at https://github.com/JosepMariaBlasco/oorexxnet is preferred for general CLR hosting, reflection, objects, events and reverse invocation. Do not maintain a rival generic .NET bridge. This sphere owns only Alchemy's adapter, qualification, live behaviour replacement, semantic provider cooperation and continuity.

## Authority boundaries
- CLR owns type, object identity, exceptions, method resolution, runtime lifetime and current implementation.
- ooRexx owns its object semantics and method providers.
- Alchemy interposition is cooperative: Inspector, Logging and Rexx overrides do not seize the CLR target.
- Current CLR behaviour is resolved at invocation; in-flight behaviour generations retain their own immutable snapshot.
- Missing member, null, omitted argument and foreign exception remain distinct.

## Evidence
Upstream README reports >500 tests across Linux, Windows and macOS with .NET 8/10, but calls API prototype. This is upstream-reported, not an Alchemy qualification result.
Alchemy v0.2.14 is the last user-qualified rollback baseline. v0.2.15 experimental code is not runtime qualified.

## Active work and missing qualification
See packages/oorexx_dotnet_alchemy_v0.2.15/docs/UPSTREAM_OOREXXNET_ADOPTION.md.
Pin upstream SHA, run upstream suite, implement Alchemy adapter, preserve Inspector v0.8.1 authority, test Android/Termux, add CI evidence and document rollback. Never promote solely on README assertions.

## Ownership
CHATGPT owns this Alchemy sphere; upstream authors own upstream bridge. No upstream source is copied into this sphere. Apache-2.0 obligations apply if later vendoring is authorized.

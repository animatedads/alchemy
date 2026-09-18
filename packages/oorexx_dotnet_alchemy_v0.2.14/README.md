# ooRexx .NET Alchemy v0.2.14

Concurrent behaviour-generation qualification candidate.

v0.2.13 establishes a stable emitted CLR type implementing a real CLR interface while the same object retains identity across C# -> ooRexx -> C# behaviour replacement.

v0.2.14 tightens the authority rule: an invocation snapshots one immutable behaviour generation before entering the implementation. Concurrent C# and ooRexx publication may advance the current generation, but an in-flight invocation completes against the generation it captured. Publication uses compare/exchange; object identity and emitted CLR type remain stable.

Qualification adds an overlapping-call gate in which generation 1 is deliberately held in-flight, generation 2 is published from ooRexx, generation 3 is published from C#, and the held generation-1 call is then released. Expected results are OLD=C#-CONCURRENT-1, current=C#-CONCURRENT-3, generations 1/2/3, stable identity/type, and ISpeaker remains true.

The next boundary after this candidate is cooperative Inspector/Clouseau interposition over the same generation authority, not raw wrapper stacking.

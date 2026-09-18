# Concurrent behaviour generation contract

A live Alchemy CLR object has stable identity and a stable CLR type. Its mutable behaviour is represented by an immutable generation object.

* Publication is atomic compare/exchange.
* Invocation reads the current generation exactly once and invokes that captured implementation.
* Replacing behaviour does not mutate an already captured generation.
* Rexx and C# are both publishers; neither runtime edits the other's in-flight call frame.
* The effective generation is monotonically increasing for successful publications.
* Reflection.Emit methods are stable thunks into the behaviour authority; emitted CLR type identity is not regenerated on method replacement.
* Foreign failure remains authoritative. Replacement does not turn a throwing foreign member into UNKNOWN fallback.

The concurrency probe deliberately blocks a generation-1 typed call after it has captured generation 1. Rexx then publishes generation 2 and C# publishes generation 3. Releasing the blocked call must return generation-1 behaviour while a fresh call returns generation 3.

## Inspector Clouseau v0.8.1 torture

The repaired Inspector is installed before the generation-1 invocation is released. A pre-existing Logging-style provider and Inspector must share one physical coordinator wrapper (provider count 2). Rexx then publishes generation 2 and C# publishes generation 3 while generation 1 is blocked. The held invocation must complete against generation 1 and subsequent dispatch must observe generation 3 without reinstalling Inspector or replacing the public Method object. This distinguishes cooperative observation from wrapper stacking or stale-method restoration.

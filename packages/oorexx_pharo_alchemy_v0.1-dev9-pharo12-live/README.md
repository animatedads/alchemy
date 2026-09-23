# ooRexx Pharo Alchemy v0.1-dev9-pharo12-live

Bidirectional object/message bridge architecture for ooRexx and Pharo.

The governing rule is deliberately small:

    everything is objects; computation crosses the boundary as messages.

This package does NOT define a JSON/subprocess RPC model. It defines the live-object
projection, identity, message, exception and re-entry contracts that the native
resident bridge must implement.

## Object model

ooRexx:
    AlchemyObject -> AlchemyForeignObject -> PharoObject

Pharo:
    Object -> AlchemyRexxObject

`PharoObject` preserves the shared Alchemy Foreign Object v0.2 UNKNOWN composition.
Unknown ooRexx messages are offered to Pharo as selectors. A genuinely absent Pharo
selector falls back to the exact pre-existing ooRexx UNKNOWN Method object. A Pharo
method which exists and throws is NOT absence.

On the Pharo side `AlchemyRexxObject>>doesNotUnderstand:` forwards the Smalltalk
message to the resident bridge, preserving selector and argument boundaries.

## Identity invariant

For resident objects:

    Pharo A -> Rexx proxy A' -> Pharo == A
    Rexx  R -> Pharo proxy R' -> Rexx  == R

No snapshot/reconstruction is permitted to satisfy this invariant.

## dev1 status

Executable contract/model package. The supplied environment contains ooRexx 5.3.0
r13196, Alchemy Foreign Object v0.2 and Alchemy Objects v0.8, but no Pharo executable
or image was present during construction. Therefore native resident Pharo execution
is explicitly NOT RUN rather than simulated.

dev3 correctly qualifies a real supplied Pharo 12 VM+image headlessly and
locks the live `doesNotUnderstand:`, Message, BlockClosure and identity semantics.
The next implementation layer is the native resident boundary and re-entry adapter.


## dev4

The complete real Alchemy Objects -> Crypto -> Foreign Runtime dependency chain is now staged and the authoritative Alchemy Foreign Object v0.2 test passes under ooRexx r13196. Pharo-specific native work must reuse/compose Foreign Runtime where applicable rather than inventing a parallel FFI layer.


## dev6 review

Reconstructed from the sealed dev4 artifact plus the recorded dev5 Foreign Runtime composition decision, then advanced to the supplied Alchemy Objects v0.8.1 inspector-repaired authority. This round focuses on maintainability: method-level contracts, consistent argument normalization, live inspection semantics and explicit identity/exception boundaries.

## dev7 native lifecycle core

The first compiled native bridge core now exists. It implements generation-safe
identity publication/revocation/pinning and sparse positional message shape.
Its executed nested-dispatch test demonstrates that foreign execution occurs
outside the registry mutex. This is bridge infrastructure qualification, not yet
a claim that the Pharo VM itself has crossed the boundary.

## dev8
Compiled runtime-neutral adapter seam with passive live discovery and honest exception/missing classification.

## dev9 — real Pharo 12 execution
The supplied Pharo 12 VM/image has now executed the bridge's live semantic gates:
runtime method amendment on the same object, actual message send, distinct
exception/missing-selector behavior, and live BlockClosure invocation/identity.
The in-process C-to-VM entry point remains the next boundary.

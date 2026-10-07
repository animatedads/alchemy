# Shared semantic-target qualification — v0.30.3

This release moves the reverse live-callable proof onto the shared Alchemy Objects
semantic-target seam.  Python owns callable identity and safe cross-thread invocation;
Alchemy Objects owns coordinator identity, semantic generation, amendment and target
revocation.

Acceptance invariants:
- Python callable identity is unchanged across R1 -> R2 -> R3 -> semantic revoke.
- Alchemy wrapper identity is unchanged across the same sequence.
- semantic generations advance 1 -> 2 -> 3 -> 4.
- Python does not cache a target Method or generation.
- semantic revocation and native object-handle revocation are independently visible.

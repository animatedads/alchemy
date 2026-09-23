# Live inspection contract — Alchemy Objects v0.8.1

The supplied repaired Alchemy Objects v0.8.1 inspector package is the authority. Inspection is observational, never dispatch authority. A cached inspector snapshot must not decide whether a live Pharo or ooRexx object currently understands a message.

* `understands:` is a live resident query and must be passive.
* ooRexx UNKNOWN remains live and composition-preserving.
* Pharo `doesNotUnderstand:` remains the unresolved-message seam.
* Behaviour changed after proxy creation must be visible without recreating the proxy.
* Inspection must not invoke a foreign method merely to discover it.
* Inspection and dispatch share the same interned identity; inspection must not manufacture a second proxy.
* Alchemy authority/provenance is not weakened by Pharo reflection.

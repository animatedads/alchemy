# ooRexx JavaScript Alchemy v0.1-dev8 — cooperative interposition

JavaScript Alchemy is a live bidirectional ooRexx ↔ JavaScript bridge following the same authority model as the .NET and Rust Alchemy participants.

## Core contract

- JavaScript objects project into ooRexx as live `AlchemyJavaScriptObject` instances.
- ooRexx objects project into JavaScript as resident live proxies.
- JS → Rexx → JS and Rexx → JS → Rexx preserve object authority identity while the runtime is resident.
- No subprocess/JSON identity surrogate is used for object crossing.
- JavaScript remains authoritative for JavaScript prototype, `typeof`, `instanceof`, exception and Promise semantics.
- Duktape is the current in-process qualification engine behind a replaceable adapter seam.

## Real Alchemy hierarchy

`AlchemyJavaScriptObject` subclasses `AlchemyForeignObject`, which in turn subclasses the authoritative Alchemy Object hierarchy. This source tree carries the Alchemy Objects v0.8.1 Inspector-repaired snapshot used for qualification. It does not fork Crypto, Foreign Runtime, Runtime Reference, OpenSSL, RxMath, or `json.cls`.

`qualify-real-alchemy.sh` validates the chosen ooRexx distribution provides `rexx`, headers, `librexx`, `librxmath.so`, and `json.cls`; it then requires explicit authoritative Crypto, Foreign Runtime and Runtime Reference roots and a resolvable system OpenSSL.

## Cooperative interposition

Dev8 separates the stable public Rexx selector from the mutable JavaScript semantic target. Once a selector is projected, JavaScript member mutation does not replace the public ooRexx Method object.

Conceptually:

```
public FOO
   |
stable Rexx trampoline
   |
cooperative coordinator / observers
   |
semantic dispatch
  / \
Rexx override   current JS property
                   |
                J1 → J2 → J3
```

A Rexx-local override is installed under a hidden selector and takes semantic precedence without displacing the public selector. Therefore JavaScript can change J2 → J3 under R1; removing R1 immediately reveals J3.

Passive inspection of projection/interposition state is Rexx-resident and does not require speculative JavaScript property access or invocation.

The shared `AlchemyForeignObject` v0.2 legacy UNKNOWN relocation machinery is not copied or silently modified here; coordinator-aware UNKNOWN composition remains a shared-base follow-on.

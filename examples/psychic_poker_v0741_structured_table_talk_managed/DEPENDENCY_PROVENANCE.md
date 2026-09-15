# v0.7.39 dependency provenance

Psychic Poker v0.7.39 retains the dependency foundation introduced and accepted in v0.7.37, originally advanced from the v0.7.36 package found in
the user-supplied consolidated recovery roll-up:

- recovery roll-up: `oorexx-libs(20260822-crypto-consolidated)(20260823-100223).zip`
- outer SHA-256: `e95f489b0088c7d11d31f3b04ac7d2bc766661c6e103a0cfaec8292ffe5203c1`
- v0.7.36 Psychic Poker ZIP SHA-256:
  `4aeb1d041dae330bbeaeca9b45e319f8af178d0b04c004875a3f586a4af7325e`

## NoSQLServer

Canonical package: `nosqlserver_v0.75.zip`

- ZIP SHA-256: `754b74050b6a838f2e4dfbcb37fbf3504081d8614f0e1ae4922cfe62f6db400b`
- vendored `nosqlserver/src/NoSQLServer.cls` SHA-256:
  `15c560afbff0566cb740953011e3946c8451530f79615223607e6f70ed6bcb32`

Only the canonical NoSQLServer source used by Psychic Poker is vendored.  Poker
continues to use CLASSIC behaviour and does not enable the optional v0.75 TUTOR
Unicode profile.

## Alchemy Objects

Canonical package: `alchemy_objects_v0.4.3.zip`

- ZIP SHA-256: `368787648a3ac88aebef169ad34dc3468df888e2dfc3272a09fdd22b67b19764`
- package manifest: 51 entries, all verified
- package tests: 22, all passed on ooRexx 5.3.0 r13196 Internal Test Version

The complete package is vendored below `deps/alchemy_objects_v0.4.3/` so the
Poker package remains independently inspectable and testable.

## ooRexx Crypto

Canonical package: `oorexx_crypto_v0.1.zip`

- ZIP SHA-256: `3eab23b5138cba889eb11ea5b93747eb14fca8da0fd4ac936a70174349ae8f3a`
- canonical `src/crypto.cls` SHA-256:
  `1bd4765c6d60251f1275790240f70cdbd55cb94ee1f50fa0a703e184e67a2d2f`
- package manifest: 14 entries, all verified
- package tests: 7, all passed on ooRexx 5.3.0 r13196 Internal Test Version

Alchemy Objects contains nested `::requires "crypto.cls"`.  ooRexx does not
consider the same byte stream loaded through a differently-qualified path to
satisfy that filename requirement.  For standalone packaging, a byte-identical
copy of the canonical `crypto.cls` is therefore present at
`deps/alchemy_objects_v0.4.3/src/crypto.cls` as a require-resolution shim.  Its
SHA-256 is the canonical value above; it is not modified source.

## Object-foundation boundary

`PokerAlchemyObject` is the local domain root.  Long-lived Poker behavioural
and service objects inherit it.  High-frequency transient value objects do not,
so the common evidence/security/contracts machinery is applied at useful domain
boundaries instead of indiscriminately to every card and decision allocation.


## v0.7.39 dependency delta

No dependency bytes changed from v0.7.38. v0.7.39 is an application-layer prompt-manifest contract change on the same NoSQLServer v0.75 / Alchemy Objects v0.4.3 / ooRexx Crypto v0.1 foundation.


## v0.7.40 authoritative roll-up rebase

Source: user-supplied `oorexxapis(20260824-140231).zip`.

- Psychic Poker baseline: `psychic_poker_v0739_prompt_manifest_contract`
- Alchemy Objects: `alchemy_objects_v0.7`
- ooRexx Crypto: `oorexx_crypto_v0.1`
- NoSQLServer: `nosqlserver_v0.77`

The Alchemy and crypto source trees are vendored under `deps/` for deterministic
package loading; NoSQLServer's authoritative `src/NoSQLServer.cls` is vendored
under `nosqlserver/src`.


### v0.7.40 byte identities

- `oorexxapis(20260824-140231).zip`: `45af34dfc81ed446bb05a13c487d2c71f23096e05bde40d6ed18570e2f3f3995`
- baseline `psychic_poker_v0739_prompt_manifest_contract.zip`: `4f06fcc1d8f2e551bd2bc2eb3a6db42f0777a841a40fa2c06a6a9560665d3afb`
- `alchemy_objects_v0.7.zip`: `a8e8e1fc080091650ee1791c997ea35ae74904b2cb658cdfdadff2a8fb7d0ee3`
- `oorexx_crypto_v0.1.zip`: `3eab23b5138cba889eb11ea5b93747eb14fca8da0fd4ac936a70174349ae8f3a`
- `nosqlserver_v0.77.zip`: `78afaa1d702d9bcfcb86ab7e56a8e3ca0c46b18519c1c4cae23bb992a2747f42`
- vendored `deps/alchemy_objects_v0.7/src/AlchemyObject.cls`: `78788922d9ad5da012d2b73e11b5fc2ab24ac5eb7943950fd84b2776ccce6ba1`
- vendored `deps/oorexx_crypto_v0.1/src/crypto.cls`: `1bd4765c6d60251f1275790240f70cdbd55cb94ee1f50fa0a703e184e67a2d2f`
- vendored `nosqlserver/src/NoSQLServer.cls`: `225704018321d15ba2897acdab228455556ca4e852200ca083a51e906eb5a76a`


## v0.7.41 structured speech dependency

- `structured_utterance_v0.3.zip` from `oorexxapis(20260824-140231).zip`.
- upstream `src/StructuredUtterance.cls` is vendored under
  `deps/structured_utterance_v0.3/src`.
- it resolves the package's existing AlchemyObject through deterministic
  REXX_PATH; no second house-base class is loaded.


### v0.7.41 byte identities

- `oorexxapis(20260824-140231).zip`: `45af34dfc81ed446bb05a13c487d2c71f23096e05bde40d6ed18570e2f3f3995`
- `structured_utterance_v0.3.zip`: `76f56332e21dc8614c07b64358dcabf0cc6ae06f0eff4aeaa9a8a18a0b727974`
- vendored `deps/structured_utterance_v0.3/src/StructuredUtterance.cls`:
  `c95216955df32580dc62a335f0e817c277102c2a6e444250ea60e059483433e6`

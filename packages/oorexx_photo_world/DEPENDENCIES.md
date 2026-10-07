# Dependencies — dev17

The machine-readable authority is `compatibility-lock.json`.

Pinned **sealed-delivery snapshots** shipped in `deps/`:
- `oorexx_maths_v0.14.zip` — SHA-256 `bdd33489141deb0a993ae134f74fb21dcb06c86d074ecca571d4f00ba022453d`.
- `oorexx_physics_world_v0.1-dev46.zip` — SHA-256 `a33845114a08dca694048964e15998c532991b73c7a3ed8f86b2eea0bb8adf87`.
- `alchemy_foreign_object_v0.2.zip` — SHA-256 `c28aea8a2136a50d52f6cef0d613d52e2811cb12bd08ad4dae597df80184e558`.
- `alchemy_objects_v0.8.2-semantic-target.zip` — SHA-256 `b91968f537851920922d87db62fb717493ea8bf3d35d0249d7ca102f36a7d02a`.

Pinned sealed-delivery Python bridge snapshot:
- `oorexx_python_macrospace_poc_v0.31.6.zip` — SHA-256 `38175f11db8e7e7de28a37e4012c92a94109b4fbcfec7fb96ee166b4d4644c6b`.
  - arbitrary positional constructor / instance / class-method calls retain the established framed argument model;
  - projected Python objects/classes and arbitrary retained ooRexx objects may cross by live identity rather than serialization;
  - natural Python operation on retained ooRexx objects supports positional arguments and live non-string Rexx return projections;
  - built and focused-qualified by dev17 against ooRexx 5.3.0 r13196 + authoritative Alchemy Objects v0.8.2 semantic-target.

The copied dependency archives do **not** become development source authority. Development should resolve the authoritative package and require the version/hash in `compatibility-lock.json`; a duplicate or stale package must not silently win through path order.

Photo Survey World owns survey semantics and world-hypothesis decisions. Maths owns reusable numerical values and higher mathematics. Macrospace/Alchemy own foreign object semantics. Python model/mesh packages provide derived evidence/capability only.


## Qualification tooling

- `oorexx_standards_enforcer.py` — static ooRexx source standards gate, SHA-256 `978d0eb24cde13e014f2aeb61bccec1e6e6049792031c593e11407af17d545d8`. It is qualification tooling, not a runtime dependency.

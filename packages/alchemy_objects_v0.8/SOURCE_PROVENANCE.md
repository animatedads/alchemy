# Source provenance

Alchemy Objects v0.8 is a semantic base-class release carried forward from the frozen `alchemy_objects_v0.7` checkpoint and the current user-supplied ooRexx project/API roll-up.

Primary current update bundle:

- `oorexxapis(20260824-162508).zip`
  - SHA-256: `0ef6ed3c7afc68be24092c609d87a6e112401d075ae4014f5a7f9ba7521e8658`
- `current/alchemy_objects_v0.7.zip` inside that bundle
  - SHA-256: `a8e8e1fc080091650ee1791c997ea35ae74904b2cb658cdfdadff2a8fb7d0ee3`
  - This is byte-for-byte the frozen v0.7 checkpoint used as the v0.8 base.
- `current/oorexx_logging_v0.3.zip`
  - SHA-256: `a8d5e7ea1e1c1001528c99a58c68f3ff6703a7a43c551505aeee2337882a8a11`
  - Logging v0.3 supplied the current generic cooperative method-interposition protocol (`__methodInterpositionAdd`, `__methodInterpositionRemove`, `methodInterpositionStatus`) and executable Alchemy-over-Logging compatibility evidence.
- `current/runtime_registry_v0.13.zip`
  - SHA-256: `93b29bda0ed24cbd042d7f1a2c20db70189195ce69decf6f95b6d20424c10988`
  - Reviewed for detached runtime execution-evidence/lifecycle conventions; v0.8 does not add a Runtime Registry dependency.
- `current/oorexx_crypto_v0.1.zip`
  - SHA-256: `3eab23b5138cba889eb11ea5b93747eb14fca8da0fd4ac936a70174349ae8f3a`
  - External crypto dependency used by the test suite; not vendored.

Interpreter used for build validation remains the supplied ooRexx 5.3.0 r13196 Ubuntu debug package:

- `oorexx-5.3.0-13196.ubuntu1604debug.x86_64(2).deb`
  - SHA-256: `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`

The project developer note continues to define Alchemy Objects as the common feature-bearing inheritance floor. v0.8 remains inside that base-class lane; no downstream package is modified here.

## v0.8 delta

v0.8 makes Alchemy telemetry cooperate safely with an already-active generic method-interposition coordinator without introducing a dependency on the Logging package:

- external coordinator first: Alchemy registers as another provider behind the existing one physical wrapper;
- Alchemy first: the historical direct object wrapper remains, preserving Logging v0.3's existing pre-existing-Alchemy contract;
- unsafe removal underneath an active outer coordinator fails without mutation rather than corrupting the coordinator's saved restore layer;
- Alchemy instrumentation add/remove operations are now `PROTECTED` Security Manager mutation surfaces;
- coordinator callbacks are authenticated by an opaque per-object identity token;
- `alchemyBaseState` reports protocol availability and the count of Alchemy methods currently using coordinated interposition.

The current Logging v0.3 package was exercised in both directions during v0.8 development: its unchanged `test_alchemy_preexisting_telemetry.rex` continues to pass, and a Logging-first/Alchemy-second test confirms one physical wrapper with two independent providers and independent release.

## Inspector lineage

Inspector lineage is unchanged from v0.7:

- Packaged `inspector/InspectorClouseau.cls` SHA-256: `5b6575f167c449fe082af7214354c7c880d805e107658ac0dcf811f396d8e134`
- `inspector/AlchemyInspectorRules.cls` SHA-256: `3ad7f744d232b38243772f1773d0ea77779b4d62c5add5d09ffc17525254e019`

The packaged Inspector remains the supplied good lineage with exactly the previously documented obsolete line removed:

```text
::requires "util/AlchemyBsfProxy.cls"
```

No BFSProxy/BSFProxy/AlchemyBsfProxy implementation is vendored or required.

v0.8 introduces no new external runtime dependency. The structural standard advances to `ALCHEMY-HOUSE-OBJECT-0.8`.

Immediate predecessor: `alchemy_objects_v0.7.zip`, SHA-256 `a8e8e1fc080091650ee1791c997ea35ae74904b2cb658cdfdadff2a8fb7d0ee3`.

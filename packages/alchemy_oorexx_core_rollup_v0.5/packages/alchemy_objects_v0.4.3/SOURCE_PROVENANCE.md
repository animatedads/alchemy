# Source provenance

Alchemy Objects v0.4.3 is a maintenance/security-compatibility release of the frozen v0.4 foundation built and validated from the following user-supplied project material.

- ooRexx 5.3.0 r13196 Ubuntu debug package: `oorexx-5.3.0-13196.ubuntu1604debug.x86_64(2).deb`
  - SHA-256: `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`
- Consolidated ooRexx libraries: `oorexx-libs(20260822-crypto-consolidated)(5).zip`
  - SHA-256: `7236b893ea52396f6a5d725c95171116f612943cc999daa69c10f5b6ef5e36b1`
- Good Inspector Clouseau source: `InspectorClouseau.cls`
  - SHA-256: `16bde993138d037ac1583ab7837e02399c8627325f490425392132309cd78855`
- Alchemy inspector rules: `AlchemyInspectorRules.cls`
  - SHA-256: `3ad7f744d232b38243772f1773d0ea77779b4d62c5add5d09ffc17525254e019`
- Legacy inspector demonstration: `demo_inspector.rex`
  - SHA-256: `873ca54c3bc91ca2f26e8f58271ab516d353f9e0b224c8032c6c7d4b77ee00e2`

The packaged `inspector/InspectorClouseau.cls` differs from the supplied Inspector source by one intentional line removal only:

```text
::requires "util/AlchemyBsfProxy.cls"
```

No BFSProxy/BSFProxy/AlchemyBsfProxy implementation is vendored or required by Alchemy Objects v0.4.3.

Packaged Inspector Clouseau SHA-256 after that single-line removal:
`5b6575f167c449fe082af7214354c7c880d805e107658ac0dcf811f396d8e134`

External consolidated `oorexx_crypto_v0.1.zip` SHA-256 used for the dependency baseline:
`3eab23b5138cba889eb11ea5b93747eb14fca8da0fd4ac936a70174349ae8f3a`

The crypto classes are consumed as an external dependency from the consolidated `oorexx_crypto_v0.1`; they are not copied into this package.

v0.3 layers execution-context quotas, crypto-locked transient methods, method policy declarations, detached relationships, structured reference-vs-observed Security Manager evidence, and explicit Clouseau key-vault traversal exclusions on the frozen v0.2 base. The Clouseau source itself remains unchanged apart from the previously documented removal of its obsolete AlchemyBsfProxy `::requires`; the additional authority/key boundary is implemented by `AlchemyInspectorBridge`.


v0.4 adds requirement assessment and rule-governed instrumentation on the frozen v0.3 implementation; no additional external source dependency is introduced.

v0.4.1 changed packaging/test-runner path handling only. v0.4.3 additionally replaces the hard-coded executable runtime signature with a live fail-closed protected-METHOD semantics probe. `ALCHEMY-HOUSE-OBJECT-0.4` remains the house-standard identifier.

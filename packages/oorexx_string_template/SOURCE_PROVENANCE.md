# Source provenance

Dev2 is a repository continuation of `packages/oorexx_string_template` from `animatedads/alchemy` main. The starting package was dev1, originally delivered as `oorexx_string_template_v0.1-dev1.zip` with SHA-256 `605c0d1f8fe05e912cfa11b30a2c2eb047923cdf3d8c9e5f048036c64be24c49` and subsequently published to the repository.

The dev2 work was rebased on repository main commit `de55fe9b468b6ebaf2a52677627083ed4b2bafd5` before modification, then rechecked against main immediately before publication.

Design constraints retained:

- preserve native ooRexx objects rather than flattening values early;
- keep authority boundaries explicit;
- provide reusable library semantics rather than application-specific template rules;
- no `INTERPRET` or arbitrary expression execution;
- qualify with the project ooRexx standards enforcer;
- make runtime qualification claims only when a real ooRexx runtime was actually executed.

No third-party template-engine source was copied into this implementation.

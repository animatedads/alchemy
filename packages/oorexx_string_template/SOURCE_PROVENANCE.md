# Source provenance

This dev1 implementation was created for the ooRexx/Alchemy component family after review of the current project conventions and recent Library state.

Design constraints carried into this package include:

- preserve native ooRexx objects rather than flattening values early;
- keep authority boundaries explicit;
- provide reusable library semantics rather than application-specific template rules;
- qualify under ooRexx 5.3.0 r13196;
- run the project ooRexx standards enforcer in strict mode.

No third-party template-engine source was copied into this implementation.

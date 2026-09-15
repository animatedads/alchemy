# Alchemy Wire UI JS v0.4-dev4 — Builder Meeting Point

Builder Studio v0.11 is validated against JS v0.4-dev4.

The generic server semantic adapter already supports the primitive families the Studio uses (`FORM`, `TOKEN_FORM`, list/collection and `SEMANTIC_RECORD`) plus later consumer primitives such as `CHOICE_LIST`. Studio therefore does not require Builder-specific rendering code.

JS dev4 also provides:

- exact definition/profile identities;
- semantic-vs-render-profile separation;
- material-token application;
- cold-cache `CREATE_INSTANCE` definition barrier;
- Queue Fabric gateway transport;
- positive-list observation plan;
- diagnostic `data-wire-*` identities on rendered roots.

The precompiled Studio package contains 23 definitions and six contextual compositions. The Builder test adapts all 23 through the real dev4 `server-semantic-adapter.js` and verifies the authoring, composition and preview surfaces are renderable forms with the expected semantic actions.

Renderer diagnostic attributes remain observation/debug evidence, never authority.


Builder v0.11 uses `web/composition-controller.js` locally rather than forking the generic JS renderer. It consumes definition `metadata.compositionHints`, applies layout presentation, switches viewport hints, and emits typed move/resize/relocate/align actions. It also derives canvas rulers/region guides and journey thumbnails from semantic composition metadata/state. The controller never edits the target project or DOM-as-source; authoritative changes return through normal Wire UI state.

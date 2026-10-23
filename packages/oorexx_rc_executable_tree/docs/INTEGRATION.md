# Integration / non-interference contract

## Separate deliverables

The existing ooDialog-on-Linux effort is an implementation of familiar ooDialog APIs and native widget behaviour. It must not depend on completion of this executable resource-tree builder.

This resource-tree package is the long-term application semantic model. It must not reimplement ooDialog UI class inheritance as the common application abstraction, and it must not force Wire UI to own application state or logic.

## Proposed contracts, not yet stable

- `rc.syntax.windows/1`: resource syntax tree, token positions, unresolved symbols and source provenance
- `rc.semantic.windows/1`: resolved typed resource records with explicit validation findings
- `rc.executable.tree/1`: uniquely identified ooRexx objects, authorized dynamic methods and event bindings
- `rc.renderer.projection/1`: deterministic, renderer-neutral view of applicable node properties

A native Win32 adapter and a Wire UI adapter should both project from the same executable state. Neither is allowed to become the authoritative state owner.

## Identity

Windows resource ID is not a globally unique ooRexx object identity. In particular, `IDC_STATIC` may repeat in a dialog. Use stable object identities and separate resource-ID indexes. Reordering the source must not silently alias application objects.

## Authority

Resource source text and JSON are untrusted data, not dynamically executable code. Only explicitly approved, discoverable operations may be compiled via `.Method~new` and installed via `setMethod`. Every tree mutation needs a target, authorization and validated schema.

## Qualification rule

100% Windows initial coverage is the acceptance goal, **not a current claim**. Corpus inventory, grammar parsing, compiler-differential checks, native UI tests, callbacks and event ordering each require separate results.

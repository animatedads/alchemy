# NewShell Source Editor Gopher sphere v0.1

Authoritative continuity sphere for the native ooRexx Source / Code / Class Editor used by NewShell development.

Current executable/source baseline:
- `oorexx_source_editor_v0.1-dev5.zip`
- SHA-256 `7b72bdf6195d6b752c92ffe0831888b834de2323fa0a887bf8dfddc45191a440`
- API `newshell.source-editor/0.1-dev5`
- runtime qualification baseline ooRexx 5.3.0 r13196.

The editor is a conventional/materialised source authority, not a replacement for Semantic Source Store / Development Desk. Development Desk owns semantic object creation and materialisation; Source Editor owns source inspection, bounded generation-checked mutation, source-aware find/grep, tree search, symbols and deterministic completion projections.

The implementation is native ooRexx. `find` is literal; `grep` delegates regex matching to ooRexx `.RegularExpression`; recursive traversal uses RexxUtil `SysFileTree`. Missing platform primitives are consumed from estate authorities rather than reimplemented locally.

Start:

    gopher --profile source-editor context source-editor --full
    gopher --profile source-editor search '<term>' --sphere source-editor

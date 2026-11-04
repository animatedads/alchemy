# ooRexx CLI UI v0.1-dev7

Renderer-neutral semantic CLI UI for NewShell and ordinary ooRexx applications.

Dev7 is driven by the Mini NotNotes list/detail/action integration. It keeps application truth in ooRexx and makes the ANSI renderer directly usable from ooRexx through a native package built against the ooRexx package API.

## Dev7 additions

- `CliUiAnsiRenderer.cls`: ooRexx-facing renderer over the native ANSI ABI.
- `src/cliui_oorexx.cpp`: renderer-only ooRexx native package. It opens/closes the ANSI renderer, draws semantic projections, sets caret, resizes and converts native key events to normalized key arrays. It contains no application/domain authority.
- `CliUiTableModel`: stable row identity, selected identity, viewport and deterministic navigation.
- `CliUiTableProjection`: column names, visible selection and bounded viewport rendering.
- `CliUiDetailModel` / `CliUiDetailProjection`: read-only title, field/value and section projection without pretending details are an editable document.
- `CliUiPromptModel` / `CliUiPromptProjection`: reusable command line with edit buffer, caret, history, completion candidate storage, submit and cancel.
- `CliUiActionMap`: application-owned key/chord to semantic command mapping.
- list -> select -> detail -> action -> list-refresh acceptance fixture.
- strict environment qualification from an unrelated current working directory.

The renderer still deliberately does **not** enable alternate-screen mode, mouse tracking, bracketed-paste capture or terminal-global selection interception.

## Package resolution

Until the Alchemy package registry/loader is the deployment authority, the supported deterministic arrangement is:

```sh
export REXX_PATH=/path/to/oorexx_cli_ui/rexx${REXX_PATH:+:$REXX_PATH}
export LD_LIBRARY_PATH=/path/to/oorexx_cli_ui/lib:/path/to/oorexx/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
```

Applications can then be launched by absolute path from an unrelated working directory. `qualify_environment.sh` proves this arrangement rather than relying on cwd-relative `::requires` resolution.

## Build and qualification

Point `REXX_HOME` at the exact ooRexx installation prefix:

```sh
REXX_HOME=/usr/local ./qualify_environment.sh
```

Qualification requires a real `rexx` executable and fails if it is absent. It compiles the C ANSI core and C++ ooRexx native package with warnings as errors, runs the original dev6 tests, the new semantic models, list/detail/action fixture, prompt fixture and a real ooRexx -> native ANSI projection. It also probes ncursesw development availability; absence leaves the curses provider fail-closed.

## Semantic boundary

```text
application truth in ooRexx
        |
semantic models/controllers
        |
semantic projections
     /       \
headless    ANSI
              |
       native renderer ABI
              |
           CliUiIo
```

No `Window/Dialog/Button/widget-tree` application hierarchy is introduced.

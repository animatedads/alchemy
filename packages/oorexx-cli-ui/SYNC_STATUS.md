# ooRexx CLI UI synchronization status

As of 2026-10-23, the available conversation source archive is `oorexx_cli_ui_v0.1-dev11.zip`.

This branch records the pending GitHub synchronization. It does **not** claim that the complete source archive has been committed. The local archive includes Rexx semantic models, ANSI/POSIX native code, ooRexx native binding, and tests. Source must be imported with its manifest and reviewed against the current main branch before merging.

## Architecture

- ooRexx application truth -> semantic UI state -> bounded screen projection -> Headless or ANSI renderer.
- Terminal-wide mouse capture, alternate screen, and bracketed-paste takeover are not enabled.
- Table selection uses stable domain identities rather than visible row positions.
- Prompt and status rows are reserved from document/table rendering.

## Qualification still required

1. Execute full `qualify_environment.sh` with a real ooRexx runtime.
2. Capture ANSI terminal output at 80x24 and 48x16 and compare reconstructed cells against headless projection.
3. Run standards checker and verify source manifest and ZIP integrity.
4. Import complete source, tests and build instructions before claiming GitHub is synchronized.

**Status: documentation synchronization only; GitHub source remains behind.**

# ooRexx CLI UI architecture — v0.1-dev1

The library exists for NewShell CLI and has two presentation paths over one semantic application model:

1. **Wire projection** — the same application can be projected through Wire like other UIs.
2. **Direct terminal projection** — native ANSI or curses renderers consume terminal semantic state directly.

The direct layer is not a toolkit object hierarchy. Application Rexx owns application truth; the renderer owns terminal mechanics.

## Hard boundaries

- NewShell CLI is a client of NewShell's internal Queue Fabric. CLI UI does not become shell-service authority.
- ANSI/curses renderers never become application/domain authority.
- IMAP owns mailbox protocol and stable `mailbox|UIDVALIDITY|UID` identities.
- SMTP Secure Stack owns signing/egress policy and relay eligibility.
- LDAP/Identity owns signing identity/authority resolution.
- Completion is descriptive and bounded; it must not execute getters or widen projected capability.
- Selection is application document/table state. Terminal-global mouse selection/copy remains available; the ANSI renderer intentionally does not enable mouse tracking or alternate-screen capture.

## Minimum semantic surface

- resize and viewport
- focus ring
- keyboard chords/commands/navigation
- editable Document with caret and selection
- Table/VirtualList with stable row identity
- styled spans (syntax, diagnostics, selections)
- status/prompt/input
- completion popup data
- semantic command dispatch

## Simplicity gates

The architecture fails review if either fixture requires terminal-specific plumbing in application code:

- editor: ooRexx/JSON/Python syntax colour + completion + selection/navigation;
- mail reader: folders/messages/body + bounded large mailbox windows + signed send through injected IMAP/SMTP/LDAP services.

## dev2 application proof rule

The editor and MailReader are acceptance applications, not places to hide missing UI
primitives. Their ooRexx composition remains small and contains no ANSI/ncurses calls.
If future editor features (selection, completion popup, syntax styling, resize) or mail
features (virtual message table, body view, compose/send) require renderer-specific
application code, the CLI UI contract must be repaired instead.


## Host I/O boundary (ABI 2)

ANSI escape semantics are not a POSIX API. `CliUiIo` therefore separates byte transport
from rendering/input decoding. The core ANSI provider compiles without POSIX, Windows,
or curses headers. Platform providers own waiting/byte transport only; they do not gain
application authority and must not silently change process-global terminal modes.

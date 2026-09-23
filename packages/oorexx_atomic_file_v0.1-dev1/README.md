# ooRexx Atomic File v0.1-dev1

API: `oorexx.atomic-file/0.1`

`oorexx_atomic_file` is an independent platform library for replacement/publication semantics. It is deliberately **not** a subpackage of `oorexx_posix`.

## dev1 implemented

- same-directory exclusive staging file creation.
- exact byte publication.
- target symlink refusal by default.
- explicit new-file mode and existing-mode preservation.
- atomic same-filesystem `renameat` replacement.
- `NONE`, `DATA`, and `FULL` durability modes.
- `FULL`: temp file `fsync` before rename plus parent-directory `fsync` after rename.
- structured result recording whether publication happened and which sync promises were achieved.
- cleanup of staging files for failures before publication.

## deliberately unavailable in dev1

- race-free expected-generation compare-and-swap.
- backup/rollback publication policies.
- owner/group inheritance.
- callback/streaming `writeWith`.
- descriptor-relative secure traversal of every ancestor component.
- directory publication.

Requests for unsupported generation or backup semantics fail closed.

## Example

```rexx
a = .AtomicFile~new
options = .AtomicFileOptions~new
options~durability = 'FULL'
r = a~replace('/var/lib/app/state.json', jsonBytes, options)
if \r~published then say r~errorStage r~errorMessage
```

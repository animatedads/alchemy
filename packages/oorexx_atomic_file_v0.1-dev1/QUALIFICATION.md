# Qualification

Qualified against the supplied Open Object Rexx 5.3.0 r13196 internal test build (64-bit, build date 2026-08-03).

Acceptance for dev1:

- native provider compiles with `-Wall -Wextra -Werror`;
- FULL publication creates and replaces files and reports parent-directory sync;
- DATA publication reports file sync without claiming parent namespace sync;
- same-directory staging works with whitespace/tab pathnames;
- target symlink replacement is refused by default;
- existing mode is preserved when requested;
- unsupported expected-generation CAS fails closed and leaves target contents unchanged;
- successful publication leaves no staging debris.

Dev1 does not yet implement generation CAS, backup policy, owner inheritance, ancestor descriptor-walk hardening or directory publication.

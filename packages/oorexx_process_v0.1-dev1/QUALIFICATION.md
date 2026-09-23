# Qualification

Qualified against the supplied Open Object Rexx 5.3.0 r13196 internal test build (64-bit, build date 2026-08-03).

Acceptance for dev1:

- native provider compiles with `-Wall -Wextra -Werror`;
- argv containing spaces, tab, newline and shell metacharacters survives exactly;
- stdin byte strings including NUL survive exactly;
- stdout/stderr are independently captured;
- non-zero child exit remains a process result rather than a provider error;
- bounded capture drains a 100000-byte producer while retaining only the configured 17 bytes;
- timeout is classified separately and terminates promptly;
- unsupported environment overlay fails closed.

Dev1 is not the complete `oorexx.process/0.1` target contract: spawn handles, environment overlays, streaming output and start-identity fencing remain open.

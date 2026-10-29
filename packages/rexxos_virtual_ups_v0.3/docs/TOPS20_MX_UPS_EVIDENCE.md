# TOPS-20 `Waiting for UPS:` — evidence and limits

**Date:** 2026-10-23. **Guest:** KLH10 on ed209j, TOPS-20 V7 installation.

Observed console fragment supplied by operator:

```
SJ  0: **** MAILS(4) 21:09:44 ****
SJ  0:  [SCHEDULER]:        Waiting for UPS:
SJ  0: **** OPR(3) 21:09:44 ****
```

Pinned KLH10 guide:
`https://github.com/PDP-10/klh10/blob/6d733f2a47644964492fd864454cbe1331655e53/doc/klt20.txt`
(section 'TOPS-20 TCP/IP - OTHER NOTES', preceding example). It identifies
periodic output as an offending `MX` job; its own `SYSTAT` example shows
`MX` under `OPERATOR` and `7-PTYCON.ATO` as the startup invocation to remove
if necessary. **The guide does not establish the expansion of `UPS` here or
demonstrate attempted email submission, a missing UPS device, or any electrical
power-state change.**

The user's hypothesis — a mail-system component unable to deliver a warning —
is plausible given `MX`, but cannot yet be asserted. The string may mean
something else to that scheduler; review authentic `MX` sources or relevant
mail-system documentation and, if safe, a read-only inspection of MX job state
and startup files. Avoid modifying `7-PTYCON.ATO` or logging out background
jobs merely to classify a message.

## Qualification ledger

- Confirmed: real TOPS-20 EXEC `@` and `HELP` output; concurrent `MAILS`, `OPR`
  scheduler notification; KLH10 guide correlates periodic notification to `MX`.
- Unknown: exact meaning of `UPS`; whether a mail transfer was attempted;
  guest physical power interface; relationship, if any, to host power monitoring.
- Forbidden inference: `Waiting for UPS:` means electrical UPS is absent.
- Separate research: Virtual UPS simulations provide synthetic power traces,
  not corrections to TOPS-20 `MX` mail scheduler.

## Working diagnostic

`python3 bin/virtual_ups.py inspect-tops20 --log console.txt`

Observational output has no authoritative hardware assertions and never
changes UPS journal or guest media. The caller retains the original capture.

## v0.3 observed-provenance refinement

The read-only classifier now computes SHA-256 over raw captured bytes *before* removing terminal NUL/ANSI controls, and associates `MAILS` and `OPR` only by line proximity. These are not causal relationships. Matching requires a complete scheduler notice line, so arbitrary command echoes such as `@PRINT [SCHEDULER]: Waiting for UPS:` do not count. Its output remains schema `virtual.ups.guest-observation/1`, with additive optional fields.

Independent example: a publicly available TOPS-20 transcript at https://blog.onodera.asia/2013/ displays `MAILS(4)` running `MX` and the same scheduler message. This corroborates the software-context observation, **not** the interpretation of UPS or an actual failed mail message. See `docs/OPERATIONS_HANDOFF.md` for the infrastructure owner boundary.

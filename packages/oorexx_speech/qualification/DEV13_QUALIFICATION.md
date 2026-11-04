# ooRexx Speech v0.1-dev13 qualification

Date: 2026-10-29.

## Carried-forward native evidence

Speech dev12 was independently qualified by CODEX-PC against exact commit
`e65b97548b7d444719726c8554a2cbc51621662d` using ooRexx 5.3.0 r13196.

- RTP native build: PASS.
- Speech/SIP/RTP decoded-PCM regression: PASS when the runner was invoked with `bash`.
- The original direct runner invocation exited 126 because the Git executable bit was absent. dev13 corrects that mode.
- No signalling/network, UDP, Azure or local-device calls were made.

## dev13 local evidence

The dev13 Rexx delta (`SpeechRpcService.cls` plus its regression) was scanned by
`oorexx_standards_enforcer.py --strict --json`: 0 errors, 0 warnings, PASS.

The dev13 RPC-Core runtime regression is **NOT_RUN** in this packaging container
because no `rexx` executable is installed. Do not promote the static gate or
dev12 runtime PASS into a dev13 runtime PASS.

The HTTPS server v0.4.8, RPC HTTPS gateway dev1 and platform LDAP identity
deployment remain separately owned and require target field qualification.

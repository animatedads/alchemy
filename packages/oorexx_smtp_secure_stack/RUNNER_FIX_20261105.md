# SMTP dev7.4 test runner repair — 5 November 2026

Architecture: Tom Dyer. Investigation, correction and test: ChatGPT (GPT-6).

## Defect and correction

`run_tests.sh` on Git main had three literal backslash-n sequences splicing independent shell commands into a single malformed command. In addition, four temporary-path suffixes were a literal `$`, rather than the intended process-specific `$$`. Both defects compromise reliable native-suite execution and fixture isolation.

Changes: replace those three escaped command separators with actual newlines; use `$$` on all four temporary paths; invoke a new standalone, dependency-free `tests/test_runner_structure.sh` at the beginning of `run_tests.sh`.

## Executed evidence

- The new structural guard PASS on a representative valid runner fixture under GNU Bash 5.2; a fixture deliberately corrupted with an escaped command separator was rejected as expected (negative control PASS).
- GitHub review-branch `run_tests.sh`: direct source check confirms six essential test invocation lines are intact, no remaining literal backslash-n delimiters, no unsafe `-$` fixture suffixes, and guard invocation included.
- `tests/test_runner_structure.sh` committed source Git blob matches the bytes of the locally executed guard: `ed2e46b0a831d7a7fdceb22205e24876fb9fbf75`.
- Independently reran original **Library** SMTP dev11 full `run_tests.sh` on the exact supplied ooRexx 5.3.0 r13196, with Socket Provider dev14, Storage Fabric dev23, Instrumentation Mesh dev8 and ooRexx `socket.cls` on `REXX_PATH`: PASS. Includes signed/unsigned inbox policy, S/MIME sign/verify, operational privacy, wire fixtures, durable delivery, outbound dispatch, and SMTP cleanup review regressions. Initial extract lacked executable shell flags and `socket.cls` path; both were local environment setup faults, corrected without changes to source bytes.
- **Not run:** full corrected GitHub dev7.4 native suite from a clean checkout, target-host live SMTP STARTTLS/LDAPS/IMAPS, operator deployment. Dev11 suite PASS is not dev7.4-suite PASS.

## Security invariants

Do not overwrite Git main SMTP 7.4 with the earlier Library dev11 dispatcher: the latter loses the definitive DATA-250 outcome on `QUIT`-raised SYNTAX, while Git main contains the merged PR #101 exception boundary. Do not infer `EMAIL_SEND` from LDAP Bind or signature; only explicit active attributed permission grants outbound submission. SMTP owns `INBOX` versus `INBOX-UNSIGNED` classification.

Submission is source/test qualification only. Installation, network effects, release acceptance and deployment receipts remain separately gated.

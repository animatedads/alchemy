# Changelog

## 0.6
- Record Terminal Machine v0.22-candidate16 as the current 3270 P0 delivery.
- Extend s3270 differential evidence to SFE extended field attributes 41/42/43/45.
- Track SA character-attribute runs and compare them through a canonical detached digest.
- Preserve NONDISPLAY secrecy: the character digest contains attribute state only, never display bytes.
- Preserve candidate15 row-geometry gates and candidate14 complete-response status/keyboard binding.
- Keep exact r13196 execution as the next release gate before live ED209Z/ED209ZZ promotion.

## 0.5
- Record Terminal Machine v0.22-candidate15 as the current 3270 P0 delivery.
- Record the independent r13196 candidate13 fixture failure and its root cause: SF plus eight data cells in an 8-column row consumed nine buffer positions.
- Enforce exact ReadBuffer row geometry in the reference adapter and fail closed on row width/count mismatches.
- Preserve candidate14 complete-response status/keyboard binding, NONDISPLAY masking and DBCS fail-closed behavior.
- Keep the next release gate as an independent r13196 rerun before live ED209 qualification.

## 0.4
- Record Terminal Machine v0.22-candidate14 as the current IBM 3270 P0 delivery.
- Bind complete s3270 peer-script evidence: ReadBuffer data, 12-field status and final ok/error.
- Derive reference rows, columns, zero-origin cursor and keyboard state from the same response instead of separately sampled facts.
- Extend semantic differential comparison to keyboard LOCKED/UNLOCKED when status evidence is present.
- Preserve NONDISPLAY masking and fail-closed DBCS/multi-byte handling.
- Record MVS Intention Runner dev10 as a downstream candidate13 consumer whose r13196/live gates remain unclaimed.
- Keep Rasen Falcon lane `terminal-machine` as the coordination lane.

## 0.3
- Record Terminal Machine v0.22-candidate13 as the current IBM 3270 P0 delivery.
- Add the independent s3270 ReadBuffer reference-adapter boundary and semantic differential comparator.
- Differential truth is field/cursor/presentation-space semantics, not screenshot equality.
- NONDISPLAY reference bytes remain masked and DBCS/multi-byte tokens fail closed until exact cell semantics exist.
- Retain candidate12 as inherited protocol/model/ownership qualification evidence; candidate13 still requires independent r13196/live execution.
- Record the Rasen Falcon `terminal-machine` lane as the coordination lane for this workstream.

## 0.2
- Promote IBM 3270/TN3270/TN3270E to the current P0 Terminal Machine implementation line while retaining TN5250 as a first-class sibling personality.
- Record v0.22 candidate10 one-writer/many-reader ownership and TerminalControlGate integration for native TN3270 sessions.
- Record candidate11 evidence-backed TK5 welcome, TSO logon, password and exact-row READY states.
- Record candidate12 reference-backed TK5 ISPF Primary Option Menu recognition from the exact Figure 17 exemplar.
- Record the protocol-neutral metering correction: TN3270 screen/round-trip facts must not be labelled TN5250.
- Record current boundaries with MVS Alchemy Services, Hercules Services, Socket Provider and ConnectSelector.
- Carry forward all v0.1 TN5250 ownership, secrecy, WLU and emulator-only rewind invariants.

## 0.1
- Initial TN5250-oriented sphere scaffold.

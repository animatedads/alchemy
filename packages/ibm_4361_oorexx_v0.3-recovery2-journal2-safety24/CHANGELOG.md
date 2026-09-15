# Changelog

## Safety22

- Added only the IBM-documented System/370 primary X'02' unassigned-opcode classification to the generic operation-exception seam; no `OP02` exists.
- Added exact X'02' permanent, pre-promotion live-journal, and live-to-permanent equivalence regressions.
- Retained recovered exact guest proof: PGMOLD `0004000160000070`, PGMNEW `00040000000002CA`, then 4,506 instructions to untouched `70 @ 000082 / 539172`.
- Added IBM manual-navigation metadata that distinguishes printed page numbers from physical PDF pages.
- Fresh qualification: 152 sources compile / 81 runtime tests pass under supplied ooRexx 5.3.0 r13196.

## Safety21

- Added only the guest-proven System/370 primary X'65' operation-exception classification to the generic architectural classifier; no `OP65` exists.
- Preserved exact recovered MVT evidence: old PSW `00040001A000006A`, complete new PSW `00040000000002CA`, then 1,703 successful instructions to untouched X'02' at `00006E / 534665`.
- Added direct, live-journal and live-to-permanent X'65' microstate regressions.
- Requalified the complete package at 147 compiled sources / 78 runtime tests on ooRexx 5.3.0 r13196.
- Used the supplied Crypto v0.8.3 Foreign Runtime/OpenSSL provider during qualification to avoid the intentionally slow portable SHA-512 fallback; emulator semantics are unchanged.
- Kept the assistant-authored `s370mvs` sphere separate and referenced its exact v0.2-dev1 digest as recovered project evidence.

## Safety20

- Added guest-proven System/370 X'D1' `MVN` / Move Numerics.
- Preserved true left-to-right destructive overlap, 24-bit address wrapping and
  unchanged condition-code semantics.
- Added exact MVT live journal retry, live-to-permanent equivalence, and a fresh
  whole-trajectory permanent-source replay.
- Advanced the real MVT frontier 1,565 successful instructions to unimplemented
  X'65' at `000066 / 532961`; no `OP65` was added.
- Made `run_tests.sh` discover standard ooRexx classes beside the selected
  runtime executable, including r13196 `json.cls` required by current Alchemy
  Objects v0.8.
- Added LLM Gopher v0.18-dev1 / `s370mvs` sphere dogfood and provenance notes.

Earlier project history remains in `CHANGES_SINCE_JOURNAL1.txt` and the
checkpoint-specific handovers.

## Safety23

- Added architecture-level specification preflight for X'70'/STE when R1 is not one of FPR 0/2/4/6; normal STE remains unimplemented and `OP70` remains absent.
- Added exact journal/live candidate proof and same-state promotion regressions at the real MVT `70E0 @ 000082 / ICOUNT 539172` frontier.
- Exposed the next causal boundary as already-implemented X'44'/EX targeting another invalid-R1 STE; Safety24 is EX-target architectural-exception propagation, not an opcode-coverage addition.
- Bounded source edit validated through LLM Gopher v0.21-dev1 against ooRexx 5.3.0 r13196.

## Safety24

- Repaired EX target architectural-exception propagation without adding OP44 or OP70.
- Proved that the exact invalid-R1 STE target of EX at `0004B6` raises specification exception attributed with EX's ILC/address, producing PGMOLD `00040006800004BA` and PGMNEW `00040000000002CA`.
- Added permanent, pre-promotion live-journal, and live-to-permanent same-state regressions for the EX-target path.
- Independent permanent whole-MVT replay advances 102,530 instructions beyond the repaired EX and reaches genuine missing X'4B' SH at `FFB5A8 / ICOUNT 641735`.
- Fresh qualification: 162 sources compile / 87 runtime tests pass under supplied ooRexx 5.3.0 r13196.

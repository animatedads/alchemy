# IBM 4361 ooRexx — Safety20 Handover

Safety20 starts from sealed Safety19 and promotes only the independently proved
System/370 X'D1' `MVN` / Move Numerics instruction.  The following X'65'
boundary is left untouched; no `OP65` method exists.

## Exact real-MVT archaeology

Sealed Safety19 reaches:

- IA `00047C`
- ICOUNT `531395`
- instruction bytes `D10004E705D1`
- PSW `000400008000047C`
- MVN length = 1 byte
- destination address `0004E7`, byte `10`
- source address `0005D1`, byte `B8`
- CC0

The first X'D1' attempt is `UNSUPPORTED` and atomic.  Exact machine/CPU/clock/
storage/device/channel state is handed in-process to journal-capable storage.
A live object-scope `OPD1` candidate is installed while an instruction journal
point is active.  Deliberately dirtied R5 and RAM are discarded by rewind while
the executable candidate survives.

Retry of the identical state produces:

- destination `10` -> `18`
- source remains `B8`
- CC remains 0
- IA advances `00047C` -> `000482`
- ICOUNT advances `531395` -> `531396`

MVT then executes 1,565 additional successful instructions before the next
unsupported boundary:

- IA `000066`
- ICOUNT `532961`
- bytes `65F000040000`
- opcode `65`
- PSW `0004000160000066`

The activated `s370mvs` Gopher sphere identifies primary X'65' as unassigned for
the System/370 target and therefore an operation-exception case.  That is a
navigation/provenance lead only for the next checkpoint: Safety20 does not
promote the classification into emulator behavior and does not create `OP65`.

## Permanent MVN semantics

Permanent `OPD1` implements the System/370 byte operation exactly:

- preserve each destination byte's high/zone nibble;
- copy the corresponding source byte's low/numeric nibble;
- process bytes left-to-right;
- therefore overlapping operands are destructive/sequential rather than
  snapshot-based;
- wrap each byte address in the 24-bit System/370 address space;
- leave the condition code unchanged.

Tests cover the recorded MVT microstate, a disjoint multi-byte case, destructive
overlap, 24-bit wrap, a live candidate, and live-candidate-to-permanent
same-state equivalence.

## Promotion proof

`test_cpu_mvn_promotion_equivalence.rex` recreates the exact recorded MVT D1
microstate in journalled storage.  It executes the successful object-scope live
candidate, rewinds, removes the live method, dirties GPR/RAM inside another
journal point and rewinds again, then executes permanent class `OPD1` from the
identical state.  Destination, source, CC and next IA must match exactly.

A separate whole-trajectory replay from original MVT media independently
observes permanent `OPD1` at `00047C`, obtains destination `18`, and reaches the
same X'65' frontier at `000066 / 532961`.

## Validation

- `COMPILE PASS 143 sources`
- `RUNTIME PASS 75 tests`
- original supplied MVTRES.350 SHA-256:
  `095b44517a85bfdd65764d22af8378e30c1437cd8539ed582e1eb45fea7c5b49`
- real media validation passes
- real IPL passes: `PSW=0000000000000080`, `CCHHR=0/0/4`
- all prior freeze/journal/live-method/program-interruption/specification-
  exception regressions remain green
- `OPD1` exists
- no `OP65` exists

Evidence:

- `evidence/mvt_safety20_d1_mvn_journal_handoff.log`
- `evidence/mvt_safety20_permanent_frontier.log`
- `evidence/safety20_compile.log`
- `evidence/safety20_full_suite.log`

## Gopher dogfood / runtime qualification

The supplied `oorexxapis(20260902-150135).zip` contains LLM Gopher v0.18-dev1
and delivered `s370mvs` sphere v0.1-dev1.  Gopher was set up against the exact
supplied ooRexx 5.3.0 r13196 `.deb` in a private environment.  It was used for
sphere lookup, archive/member navigation, workspace archive preflight,
source-symbol lookup, language-rule checks, SHA fencing and the bounded
`OPD1` class edit.

Dogfood also exposed useful capability gaps: Gopher does not yet materialise an
editable ZIP tree, create a new text test file, or edit shell source.  Those
fallbacks were recorded through `dogfood.escape.record` rather than hidden.
Its package-stage rule additionally required a `CHANGELOG.md`; Safety20 adds
one while retaining the historical `CHANGES_SINCE_JOURNAL1.txt` ledger.

The selected private r13196 runtime carries `json.cls` beside `rexx`.  Because
current Alchemy Objects v0.8 requires that standard class, `run_tests.sh` now
discovers the selected runtime's standard-library directory automatically and
adds it to `REXX_PATH`.  Qualification therefore no longer relies on a caller-
supplied runtime-bin path.

## ooRexx argument discipline

Executable-probe command-line text continues to use `parse arg`.  Object-
bearing helper procedures/methods use `use arg` so object identity is
preserved.

## Next task

Start from sealed Safety20 and investigate X'65' at `000066 / 532961` as an
architectural operation-exception boundary.  The Gopher sphere says it is
unassigned on the System/370 target, but repeat the established evidence-first
workflow: first attempt must remain atomic/unsupported, then live-classify and
deliver the operation exception under journal rewind, prove exact old/new PSW
behavior and real-MVT forward progress, promote only the generic classifier,
and keep `OP65` absent.

Normal X'5D' Divide remains a separate visible coverage item and is still not
implemented.

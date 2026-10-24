# Standards review — dev7.4

Targeted review using Claude's `oorexx_standards_enforcer.py`, followed by real ooRexx r13196 compile/runtime checks for the September candidate and a source-level publication pass in October.

## Confirmed repairs

All checker-reported `AMPERSAND_SHORTCIRCUIT` findings in the band source were rewritten as explicit nested conditions where guarding was intended.

All 21 prior `PLUS_ZERO` errors were then repaired using the ooRexx rule clarified during review: **check numeric; do not make numeric**. `+` is method dispatch and may have arbitrary object semantics. Numeric constructor/input boundaries now validate with `datatype(value,'N')` or `datatype(value,'W')` as appropriate and retain the original validated value. `AsciiTab` likewise validates its parsed fret digits before using the original digits value.

## Runtime evidence retained from September

- `AsciiTab.cls`, `BandConcurrentRenderer.cls`, `GuitarPhysics.cls`, and `MidiReader.cls` compiled on ooRexx 5.3.0 r13196 debug.
- `test_tab_parser.rex`: PASS.
- `test_midi_reader_synthetic.rex`: PASS.

Those are historical candidate results. The October GitHub publication environment does not contain an ooRexx executable, so no new runtime PASS is claimed for the numeric-guard edits.

## Enforcer result

Historical starting point: 30 ERROR / 48 WARN.
After the first targeted repair: 21 ERROR / 48 WARN.
After explicit numeric-boundary repair on the GitHub publication tree: **0 ERROR / 48 WARN / PASS**.

All 48 remaining WARN findings are `LOOP_INVARIANT`. This is a heuristic and is noisy in object/stateful audio loops where state changes through messages even when the loop-control variable is not textually present on the right-hand side. They remain review prompts, not automatic rewrite instructions.

## Boolean evaluation rule

`&`, `|`, and `&&` must be used only when evaluation of every operand is valid and intended. When legality, state access, cost, or side effects on a later expression depend on an earlier condition, use explicit nested control flow instead.

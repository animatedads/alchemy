# s370mvs sphere v0.3-dev1

## Purpose

A durable System/370 + OS/360 MVT/MVS engineering repository for opcode identity,
operand behavior, exception precedence, complete-PSW interruption rules, HFP rules,
guest archaeology procedure, exact project checkpoints and source provenance.

The assistant is an author of this sphere. The sphere has an independent lifecycle
from executable emulator safety checkpoints and is delivered separately.

## High-value lookups

```sh
gopher --profile s370mvs lookup opcode=5D --sphere s370mvs
gopher --profile s370mvs lookup opcode=D1 --sphere s370mvs
gopher --profile s370mvs lookup opcode=02 --sphere s370mvs
gopher --profile s370mvs lookup opcode=70 --sphere s370mvs
gopher --profile s370mvs lookup opcode=44 --sphere s370mvs
gopher --profile s370mvs lookup checkpoint=safety23 --sphere s370mvs
gopher --profile s370mvs search 'use arg parse arg object identity' --sphere s370mvs
```

## Evidence boundaries

IBM documentation defines architecture. Executable references corroborate sequencing.
Exact project evidence says what this emulator and historical guest did at one exact
state. Live-candidate proof, permanent-source replay and a sealed checkpoint are
separate maturity levels and must not be conflated.

## Current sealed project knowledge

- Safety20: D1/MVN sealed, destructive left-to-right overlap preserved.
- Safety21: primary X'65' unassigned -> operation exception, no OP65.
- Safety22: primary X'02' unassigned -> operation exception, no OP02.
- Safety23: X'70' is STE; historical R1=E is invalid for short/long HFP and causes
  specification exception before normal STE coverage. No OP70; normal STE remains
  unimplemented.

Safety23 then executes 32 further instructions to `44 @ 0004B6 / ICOUNT 539205`.
The already-implemented EX builds transient target `70E005C84780`, another invalid-R1
STE. The next causal task is therefore **EX target architectural-exception
attribution/propagation**, not adding OP44 or normal OP70.

## Development discipline

Use freeze for durable evidence, journal points for exact-state rewind, and live
insert/replace/remove methods for hypotheses. Promote only after same-state proof and
an independent permanent-source trajectory. For ooRexx object-bearing helper
arguments use `use arg`; reserve `parse arg` for textual/scalar parsing.

# IBM 4361 ooRexx — Safety23 Handover

Safety23 starts from the exact sealed Safety22 artifact and promotes only the
System/370 invalid-register specification preflight for `70 / STE — Store,
Short`. There is still no `OP70`; normal STE storage semantics remain
unimplemented. The next boundary is an already-implemented `44 / EX` whose
target instruction is another invalid-register STE, exposing target-exception
propagation as the next causal task.

## Base identity

- base artifact: `ibm_4361_oorexx_v0.3-recovery2-journal2-safety22.zip`
- base SHA-256: `bd4ada1fe3ad6da3b97cbfe645e1130b7f0e625c6e3cd2d13a53d50239968f91`
- original supplied `MVTRES.350` SHA-256:
  `095b44517a85bfdd65764d22af8378e30c1437cd8539ed582e1eb45fea7c5b49`

## Architecture classification

IBM `System/370 Reference Summary` GX20-1850-5 identifies primary X'70' as
`STE — Store, Short`, RX format. IBM `System/370 Principles of Operation`
GA22-7000-6 states that short/long floating-point operands designate only FPR
0, 2, 4 or 6; another R field suppresses the operation and raises specification
exception.

The exact MVT frontier is `70E0...`, therefore R1=`E` is architecturally
invalid. This is an operand-validity exception, not permission to fabricate
normal STE behavior.

Navigation metadata is retained in `evidence/safety23_ibm_ste_source.json`.

## Exact real-MVT journal proof

`probe_mvt_safety23_70_specification_journal_handoff.rex` begins from real IPL
with a live pre-Safety23 classifier shadowing the permanent method so the
historical X'70' invocation is first observed as a genuine implementation gap.
It proves:

- frontier `70 @ 000082`, ICOUNT `539172`
- bytes `70E000000000`, PSW `0004000190000082`
- first execution `UNSUPPORTED`, atomic; no `OP70`
- install candidate validity classifier while the instruction journal is active
- deliberately dirty GPR/RAM and abort
- exact CPU/RAM state rewinds; candidate method survives
- retry stores program-old PSW `0004000690000086`
- complete program-new PSW `00040000000002CA` loads
- instruction count advances once to `539173`
- candidate classifier is then removed so continued guest execution returns to
  permanent source
- 32 further guest instructions execute successfully
- next boundary: `44 @ 0004B6`, ICOUNT `539205`
- EX instruction bytes `440004F45010`
- effective target instruction `70E005C84780`
- executor status `UNSUPPORTED_EX_TARGET`

The target is again STE with R1=`E`. `OP44` already exists. The next task is
therefore to carry an architectural target exception through EX correctly.

## Permanent source change

`architecturalSpecificationException()` remains an operand-validity preflight
executed before normal instruction-implementation coverage. Safety23 adds only:

`opcode 70 && R1 not in {0,2,4,6} -> specification exception`

The method was edited through LLM Gopher v0.21-dev1 bounded ooRexx method
editing with stale-source SHA fencing and exact r13196 translation validation.
No `OP70` method was added.

## Focused regressions

- `test_program_specification_interrupt_70.rex`
  - exact invalid-R1 program interruption
  - no storage side effect
  - valid selectors 0/2/4/6 remain `UNSUPPORTED`
  - invalid preflight wins even if dummy live `OP70` exists
- `test_program_specification_interrupt_70_live_trial.rex`
  - pre-promotion unsupported/atomic state
  - live classifier survives journal rewind while dirty CPU/RAM is discarded
  - exact old/new PSWs and ICOUNT
- `test_program_specification_interrupt_70_promotion_equivalence.rex`
  - live candidate -> rewind -> remove -> permanent fallback
  - same-state result equivalence

## Independent permanent whole-MVT replay

`probe_mvt_safety23_70_permanent_frontier.rex` is the separate permanent-source
trajectory. It must reproduce the exact X'70' interruption and the same EX
target boundary. It exits zero and independently reproduces PGMOLD `0004000690000086`, PGMNEW `00040000000002CA`, and the same `44 @ 0004B6` EX-target boundary.


## Qualification

- ooRexx 5.3.0 r13196: **157 `.cls/.rex` sources compile**
- **84/84 runtime tests pass**
- original `MVTRES.350` passes
- real MVT IPL passes with `PSW=0000000000000080`, CCHHR `0/0/4`
- LLM Gopher v0.21 package check: **0 breaches / 0 blockers**
- audit: no `OP70`; existing `OP44` is unchanged in Safety23

## Next task — EX target architectural exception propagation

Start only from sealed Safety23. Do not add `OP44`: EX is already implemented.
Do not add normal `OP70`: the observed target is still invalid-R1 STE.

The current EX preflight checks only `supportsInstruction(target)`. It therefore
returns `UNSUPPORTED_EX_TARGET` before asking whether the transient target has
an architecturally qualified specification/operation exception. Safety24 must
prove the System/370 EX semantics for such a target at the exact `0004B6`
historical state, including correct interruption old-PSW instruction address /
ILC attribution. Use journal/live method replacement first, then permanent
promotion and whole-guest forward progress.

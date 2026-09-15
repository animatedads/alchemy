# IBM 4361 ooRexx — Safety24 Handover

Safety24 starts from the exact sealed Safety23 artifact and repairs only the
architectural-exception preflight for an instruction executed by System/370
`44 / EX — Execute`.  It does not add `OP44` (EX already exists) and does not
add `OP70` (normal STE remains unimplemented).

The exact MVT case is EX at `0004B6`, targeting `70E005C84780`.  The transient
target is the already-qualified invalid-R1 STE case.  Safety24 proves that the
resulting specification exception is attributed to EX's instruction address
and ILC, then follows real MVT more than one hundred thousand instructions to a
new ordinary instruction-coverage frontier.

## Base identity

- base artifact: `ibm_4361_oorexx_v0.3-recovery2-journal2-safety23.zip`
- base SHA-256: `78ec6e899ac4825658116326fe25395efe821c06d0745475bd8cec206c1dcefc`
- authored `s370mvs` sphere used for navigation: `s370mvs_gopher_sphere_v0.3-dev1.zip`
- sphere SHA-256: `8516e443019675932369613c1c8dcf834ffbc407ddb1552ab469fbc29dd2530e`
- API roll-up: `oorexxapis(20260906-192237).zip`
- API roll-up SHA-256: `aa1709f24b4a8473fcfb99f36c11c4bb718b9ce0e30d7a4f439d5df8cbdfeafb`
- original supplied `MVTRES.350` SHA-256:
  `095b44517a85bfdd65764d22af8378e30c1437cd8539ed582e1eb45fea7c5b49`

## Architectural rule proved

System/370 EX executes the transient target instruction, but program-exception
information is attributed using EX itself for the current instruction's PSW
advance / instruction-length information.  For the exact four-byte EX at
`0004B6`, a target specification exception therefore saves the next address
`0004BA` with EX ILC=2.

The target instruction is `70E005C84780`; Safety23 already proved that X'70'
STE with R1=`E` is an invalid floating-point-register selector and raises
specification exception before normal STE coverage.

## Exact real-MVT journal/live proof

`probe_mvt_safety24_ex_target_specification_journal_handoff.rex` preserves the
pre-Safety24 behavior at the exact historical state, then uses live `step`
replacement while the instruction journal is active.  The recorded proof is:

- EX frontier: `44 @ 0004B6`, ICOUNT `539205`
- bytes: `440004F45010`
- transient target: `70E005C84780`
- first execution: `UNSUPPORTED_EX_TARGET`, atomic
- install Safety24 `step` hypothesis while journalled
- deliberately dirty GPR/RAM, then abort
- CPU/RAM rewind exactly; live method survives
- retry returns `OK`
- program-old PSW: `00040006800004BA`
- complete program-new PSW: `00040000000002CA`
- ICOUNT advances exactly once to `539206`
- `OP70` remains absent
- after live proof the candidate is withdrawn and execution returns to
  permanent source
- at least 100,000 subsequent guest instructions execute successfully in the
  original live-handoff run

Evidence:
`evidence/mvt_safety24_ex_target_specification_journal_handoff.log`.

## Permanent source change

Only `IBM370Executor~step` changes.  During EX preflight it now asks whether the
transient target has a qualified architectural specification exception before
checking ordinary target implementation coverage.  If so it calls the existing
`programInterruptSpecification()` using EX's `ia` and `len`, records
`EX->target` evidence, advances the architectural instruction count once, and
returns through the generic interruption path.

The bounded edit was committed with LLM Gopher v0.21-dev1 using stale-source
SHA fencing and ooRexx 5.3.0 r13196 translation validation.

No normal STE semantics were added and no `OP70` exists.

## Same-state regressions

- `test_program_specification_interrupt_ex_target_permanent.rex`
  proves permanent-source PGMOLD/PGMNEW/ICOUNT and no OP70.
- `test_program_specification_interrupt_ex_target_live_trial.rex`
  shadows the permanent step with the exact pre-Safety24 method, proves the
  old unsupported boundary is atomic, replaces it live, rewinds dirt, and
  retries the identical state.
- `test_program_specification_interrupt_ex_target_promotion_equivalence.rex`
  executes the live candidate, rewinds, removes it, and proves permanent source
  produces the identical PSW, old PSW, ICOUNT and target evidence.

## Independent permanent whole-MVT replay

`probe_mvt_safety24_permanent_frontier.rex` contains no Safety24 live method.
It starts from the original `MVTRES.350`, reaches the exact EX state and proves:

- before EX: `IA=0004B6`, `ICOUNT=539205`, PSW `00040000800004B6`
- after permanent EX handling:
  - status `OK`
  - IA `0002CA`
  - ICOUNT `539206`
  - PGMOLD `00040006800004BA`
  - PGMNEW `00040000000002CA`
- real MVT then executes **102,530 further successful instructions**
- new boundary:
  - `4B @ FFB5A8`
  - ICOUNT `641735`
  - bytes `4B80D24B1684`
  - PSW `00040000A0FFB5A8`

IBM System/370 instruction summaries identify primary X'4B' as
`SH — Subtract Halfword`, RX format.  That is a genuine missing instruction,
not an exception-classification artifact.

## Qualification

- ooRexx 5.3.0 r13196: **162 `.cls/.rex` sources compile**
- **87/87 runtime tests pass**
- original `MVTRES.350` passes
- real MVT IPL passes with `PSW=0000000000000080`, CCHHR `0/0/4`
- the four durable-freeze qualification processes use the supplied Crypto
  v0.8.3 Foreign Runtime v0.22.6/OpenSSL provider only as a test accelerator;
  emulator runtime dependencies and freeze semantics are unchanged
- no `OP70`; existing `OP44` remains the EX implementation

## Next task — Safety25 / X'4B' SH

Start only from sealed Safety24.  Pin SH semantics and exception/CC ordering
from authoritative System/370 documentation, capture the exact `FFB5A8 /
641735` guest operands, then use the established journal/live-method workflow:
unsupported atomic boundary -> insert SH candidate -> rewind -> exact retry ->
remove live candidate -> permanent same-state equivalence -> whole-MVT replay.

Do not infer later-architecture behavior where System/370 differs.  SH is
signed 16-bit-memory operand subtraction into a 32-bit GPR and must preserve the
architecture's fixed-point overflow/condition-code rules rather than using host
integer behavior implicitly.

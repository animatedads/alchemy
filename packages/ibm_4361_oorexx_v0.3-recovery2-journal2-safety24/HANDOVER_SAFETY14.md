# IBM 4361 ooRexx — Safety14 Handover

Safety14 starts from sealed safety13 and resolves the address-zero frontier without inventing an opcode.

## Causal finding

The final control transfer into zero is architecturally legitimate: MVT executes `05E6` (BALR R14,R6) with R6=0. Low core already holds program-new PSW `00040000000002CA` at X'68'. The X'00' fetch is therefore a deliberate operation-exception path used by MVT to enter its program-check handler.

## Implemented architecture

`IBM370Executor` now separates an architecturally undefined operation from emulator instruction coverage:

- `architecturalOperationException(raw)` classifies the independently proved primary X'00' case.
- `programInterruptOperation(inst,ia,len)` performs the qualified System/370 BC-mode operation-exception interruption.
- X'00' remains absent from `nativeOps`; there is no `OP00` method.
- other unsupported opcodes remain atomic `UNSUPPORTED` boundaries.

For the qualified BC-mode path the executor advances the interrupted instruction by its ILC, sets interruption code 1 in the old PSW, stores it at prefix+X'28', loads the complete program-new PSW from prefix+X'68', and counts the interrupting instruction once. EC-mode detail is deliberately fail-closed pending separate qualification.

## Exact live archaeology proof

`tests/probe_mvt_program_interrupt_journal_handoff.rex` avoids journalling the already-known half-million-instruction lead-in. It runs that deterministic prefix on ordinary sparse RAM, captures explicit machine/CPU/clock/storage/device/channel state at IA zero, rehydrates it into `IBM370JournaledStorage`, verifies the handoff, then creates the journal checkpoint.

The proof records:

- IA `000000`, IC `513272`, PSW `0004000A60000000`.
- low-core program-new PSW `00040000000002CA`.
- first X'00' remains `UNSUPPORTED` and atomic.
- object-scope operation classifier + interruption implementation are installed during the checkpoint.
- deliberate R5/RAM dirt rewinds; executable hypothesis survives.
- retry stores exact program-old PSW `0004000160000002`.
- complete program-new PSW loads; IA becomes `0002CA`.
- no `OP00` exists.
- MVT makes 34 further instructions of forward progress.
- next unsupported instruction: `1E` at IA `01A482`, IC `513307`, fetch window `1EAB91C01000`.

This is another concrete advantage of journalable elements: expensive, already-known history can remain outside the journal, while the exact historically interesting state is handed into a journal-capable substrate for reversible same-state code archaeology.

## Promotion proof

The regression suite includes native interruption tests, live rewind/retry, prefix-relative low-core handling, and candidate-to-permanent equivalence. The live candidate is executed, the journal rewinds the identical microstate, object methods are removed, and the permanent class implementation produces the same current PSW, old PSW and instruction count.

## Validation

- `COMPILE PASS 116 sources`
- `RUNTIME PASS 57 tests`
- original supplied `MVTRES.350` passes media validation
- real IPL passes: `PSW=0000000000000080`, `CCHHR=0/0/4`
- freeze and journal remain separate features and both suites remain green

See `evidence/mvt_safety14_program_interrupt_journal_handoff.log`, `evidence/safety14_full_suite.log`, and `VALIDATION_SAFETY14.txt`.

## Next task

Do not touch X'00'. Safety14 has resolved it as a program interruption.

The next genuine guest-driven missing instruction is `1E` / ALR (Add Logical Register) at `01A482`, IC `513307`. Trial it object-scope against the exact guest state, rewind/retry, promote only after forward progress, then cut safety15.

Project-local SSC qualification remains pinned to exact v0.2.2 unless explicitly superseded.

# IBM 4361 ooRexx — Safety21 Handover

Safety21 starts from the exact sealed Safety20 artifact and promotes only the
System/370 primary X'65' architectural operation-exception classification.
There is no `OP65` method.  The next X'02' boundary is deliberately untouched.

## Base identity

- base artifact: `ibm_4361_oorexx_v0.3-recovery2-journal2-safety20.zip`
- base SHA-256: `7e7019c503ae62ef738315e154e533acb3e7fbc19be26dd69838ddc102645913`
- original supplied `MVTRES.350` SHA-256:
  `095b44517a85bfdd65764d22af8378e30c1437cd8539ed582e1eb45fea7c5b49`

## Exact real-MVT evidence carried into the seal

The separately delivered assistant-authored `s370mvs` Gopher sphere
v0.2-dev1 was cut after the Safety21 live and permanent replay work and is the
durable recovered evidence source for the exact guest trajectory in this
continuation chat:

- sphere artifact: `s370mvs_gopher_sphere_v0.2-dev1.zip`
- sphere SHA-256: `bd20213258b94004774e5b01ae266e40909953c24d96447b98af54716e53ed5f`
- frontier: X'65' at IA `000066`, ICOUNT `532961`
- bytes: `65F000040000`
- pre-interruption PSW: `0004000160000066`
- first pre-promotion execution: `UNSUPPORTED`, atomic
- live operation-exception classifier installed while journal state is active
- rewind restores machine state while classifier survives
- exact program-old PSW: `00040001A000006A`
- complete program-new PSW: `00040000000002CA`
- no `OP65`
- 1,703 further successful guest instructions
- next untouched frontier: X'02' at IA `00006E`, ICOUNT `534665`
- X'02' bytes: `02CA00020000`
- X'02' PSW: `000400016000006E`

The recovered structured lookup is retained as
`evidence/safety21_gopher_opcode65_recovered_evidence.json`; the active sphere
registry is retained separately in `evidence/safety21_gopher_sphere_registry.json`.
The sphere remains a separate artifact and is not vendored into this emulator
package.

A fresh long whole-MVT lead-in was also attempted in this continuation chat
against the same original disk image under the supplied r13196 debug runtime.
The execution tool interrupted that deterministic CPU-bound lead-in before the
frontier, so no replacement guest log is manufactured here.  The prior exact
live/permanent proof is instead recovered from the separately sealed Gopher
sphere and is paired with fresh local microstate and full-suite qualification
below.

## Permanent source change

`architecturalOperationException()` remains a positive architecture-specific
allow-list.  Safety21 adds X'65' to the already-qualified X'00', X'FF', X'C4'
and X'62' cases:

`00 | FF | C4 | 62 | 65`

The change was applied through LLM Gopher v0.18-dev1 bounded ooRexx method
editing with SHA-256 stale-source fencing and exact r13196 `rexxc` validation.
No OPxx implementation was added.

## Fresh Safety21 microstate qualification

Three new regressions recreate the exact X'65' machine state:

- `test_program_operation_interrupt_65.rex`
- `test_program_operation_interrupt_65_live_trial.rex`
- `test_program_operation_interrupt_65_promotion_equivalence.rex`

They prove:

1. permanent X'65' classification delivers the operation exception;
2. program-old PSW is exactly `00040001A000006A`;
3. the complete program-new PSW `00040000000002CA` is loaded;
4. instruction count advances exactly once;
5. a Safety20 classifier shadow still leaves X'65' unsupported/atomic;
6. the live candidate survives journal rewind while deliberately dirty GPR/RAM
   state is discarded;
7. removing the live classifier and retrying the identical microstate through
   permanent source produces the same PSW/old-PSW/instruction-count result;
8. `OP65` remains absent;
9. unrelated implementation gaps still remain `UNSUPPORTED`.

## Qualification

Fresh qualification against supplied ooRexx 5.3.0 r13196 is green:

- `COMPILE PASS 147 sources`
- `RUNTIME PASS 78 tests`
- original real media passes
- real MVT IPL passes with `PSW=0000000000000080`, `CCHHR=0/0/4`
- all prior freeze/journal/live-method/operation/specification-exception
  regressions remain green
- all three new X'65' tests pass
- `OP65` absent

Current Crypto v0.8.3 in the supplied API roll-up has a deliberately slow
portable SHA-512 fallback.  For qualification only, its own qualified
Foreign Runtime/OpenSSL provider was installed in the test process using
Foreign Runtime v0.22.6 and Runtime Reference v0.4 from the same roll-up.  This
changes execution provider, not Crypto or emulator semantics; it avoids an
otherwise multi-minute portable hash path in freeze regressions.

Evidence:

- `evidence/safety21_full_suite.log`
- `evidence/safety21_compile.log`
- `evidence/safety21_runtime.txt`
- `evidence/safety21_gopher_opcode65_recovered_evidence.json`
- `evidence/safety21_gopher_sphere_registry.json`

## ooRexx discipline retained

Object-bearing helper arguments use `use arg`; command-line/scalar parsing uses
`parse arg`.  Journalled architectural state and live executable hypotheses
continue to have independent lifetimes.

## Next task — X'02'

Start only from sealed Safety21.  The current `s370mvs` sphere deliberately
marks primary X'02' as `PENDING_IBM_DOC_TABLE_CONFIRMATION` and warns not to
confuse it with BCTR/X'06'.  Pin X'02' to authoritative System/370 Principles
of Operation material before changing emulator behavior.  If it is unassigned,
prove an operation exception through the generic classifier; if it is assigned,
implement only after exact guest semantics are established.  Do not create an
`OP02` merely to make MVT progress.

Normal X'5D' Divide remains a separate coverage item and remains unimplemented
apart from the already-qualified odd-R1 specification-exception preflight.

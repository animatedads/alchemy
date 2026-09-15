# Changelog

## v0.31-dev5-journal1

- Added architectural KL10A/TOPS-20 write-protection page-fail delivery. A denied write no longer escapes as a host-side `SYNTAX`; the CPU writes the non-KLB TOPS-20 UPT fault block and transfers through UPT+0503.
- Added `test_cpu_tops20_page_fault_delivery.rex`, proving fault word `111000,,772253`, protected-word preservation, saved next-PC and guest vector transfer to `044414`.
- Integrated Journal Pointed State v0.1 as the hot reversible state substrate. `KL10Memory` journals only its write overlay and coalesces writes inside one instruction event; mapped tape/zero pages are not copied per checkpoint.
- Added `KL10Journal.cls` with State-of-the-Nation participants for CPU core/128 ACs and stateful devices, plus instruction begin/commit/abort/restore boundaries.
- Added branch/rewind regression and TOPS-20 page-fault rewind/replay regression. Old and repaired futures remain reconstructible.
- Added live unsupported-opcode extension seam `OPooo` and `installLiveInstructionMethod()`. The recovery regression proves: refuse -> rewind -> install object method -> retry same instruction -> continue, without restart.
- Added native zlib compressed cold checkpoints using `KL10Deflate.cls`, carrying the msqlshim v0.21.1 `::options digits 30` Adler-32 precision repair. The regression checks the external Adler-32 oracle `7247BAAC` before state save/load round-trip.
- Durable `KL10_STATE/1` schema is unchanged; journal history is deliberately not serialized into cold architectural checkpoints.
- Historical NXM sizing regression remains green: physical page `1235` is not materialized and APR NXM `002000` remains architectural.
- Validation under ooRexx 5.3.0 r13196: all shipped Rexx/class/tool sources compile; core suite PASS=54, SKIP=0.

## v0.31-dev4

- Proved the third authentic read: one 512-word LAST CCW into physical `001000..001777`.
- Added `test_third_read_real_state.rex`.
- Added `tools/KL10RunContinuous.rex` for bounded execution that does not stop at every reel movement.
- Continued the real MTBOOT stream through 21 complete records, reaching tape byte 53928 with no new RH20 refusal.

- Implemented bounded RH20 multi-CCW forward channel transfers.
- One pending tape record may now be scattered over consecutive op-4/op-6 CCWs; LAST must consume the complete record.
- Preserved physical DMA semantics across addresses `000000..000017`, proving no AC-window aliasing.
- Real MTBOOT second READ FORWARD now advances the authenticated TU45 from byte 2568 to 5136 and transfers record two through `762000/762001`.
- Added `test_rh20_multiccw_read.rex` and `test_second_read_real_state.rex`.
- Generalized the steady MTBOOT probe accelerator to the live stack pointer rather than one hard-coded stack slot.
- Added a phase-one complete region-cycle accelerator; full frozen-state equivalence proves a 2542-instruction cycle.
- Region-cycle proof caught and fixed an unwanted CST MODIFIED side effect by using the already-validated physical address for the persistent `772272` update.
- No state-schema bump; current schema remains `3d662969aa66a35bc263fd759a40f274956999b9bec6419c3cb418d4105c9f2f`.

## v0.31-dev3

- Added top-level `run_tests.sh`, matching the component convention used by Terminal Machine, Queue Fabric, Runtime Registry and other current ooRexx packages.
- Modes: `core`, `tape`, `states`, `integrations`, and default `all`.
- The core runner compiles every shipped `.cls`/`.rex` source and executes 49 self-contained regressions.
- Historical reel/checkpoint tests are activated with explicit fixture environment variables; missing external archaeology is reported as `SKIP`.
- Queue Fabric v0.8.1 and Terminal Machine v0.5 integration tests are activated by `QUEUE_FABRIC_ROOT` and `TERMINAL_MACHINE_ROOT`.
- `run_tests.sh all` without external fixtures: `PASS=49 SKIP=16`, rc=0.
- Fixed the runner cleanup path under `set -u`; the initial implementation's function-local RETURN trap could fail after an otherwise green suite.
- No architectural or state-schema change from v0.31-dev2.

## v0.31-dev2

- Added first-class detached `KL10FrozenState` objects.
- Added `KL10State~freeze(cpu[,metadata])`; compatibility `save()` now performs freeze + persist.
- Replaced per-record state-file `lineout()` calls with in-memory join plus one `charout()`.
- Replaced load-side per-record digest-verification `lineout()` calls with in-memory canonical join.
- Frozen state owns encoded bytes, copied metadata, schema identity, memory digest, record count and byte count.
- Repeated saves of one frozen 3.68 MB checkpoint measure in milliseconds under ooRexx 5.3.0 r13196.
- Large-state load/verification dropped from roughly 17 s to roughly 5.8 s in the same debug runtime.
- Added `test_state_fast_freeze`: repeated-save identity, compatibility-wrapper identity, reload and post-freeze live-machine/metadata mutation isolation.
- No KL10 architectural state-schema change; current schema remains `3d662969aa66a35bc263fd759a40f274956999b9bec6419c3cb418d4105c9f2f`.
- Validation: 124/124 Rexx/class/tool sources compile; fast-freeze, fail-closed, first-read and execution-accelerator regressions pass.

## v0.31-dev

- Added `KL10Execution.cls` and explicit `KL10ExecutionRunner`; `KL10CPU~step`
  remains the unaccelerated reference semantic path.
- Added a proved-equivalent `774670..774672` MTBOOT clear-loop collapse with
  exact `3*N-1` architectural ICOUNT preservation.
- Added a proved-equivalent 32-instruction MTBOOT physical-memory probe-cycle
  collapse rooted at `774542`.
- Probe acceleration fingerprints the historical routine, validates stack and
  scratch state, preserves two PAG CLRPT generations, and re-checks MAP for
  every candidate page.
- MAP status bits such as MODIFIED are accepted only when MTBOOT's actual
  `100000` mapping-valid test still succeeds and the mapped right half remains
  the requested page.
- Candidate `777000` is deliberately not accelerated; the real 36-bit ADDI
  carry and exit path execute instruction by instruction.
- Fixed the new runner's 36-bit numeric handling by explicitly using
  `numeric digits 30` in architectural-word methods.
- Added `tools/KL10Run.rex`.
- Added regression coverage for the clear accelerator, ordinary MAP probe
  accelerator, and the real `160000,,762000` modified-MAP probe case.
- Validation under ooRexx 5.3.0 r13196: 122/122 Rexx/class/tool sources compile;
  all three new accelerator equivalence regressions pass.

## v0.30

- Added a mounted TM03/TU45 transport behind RH20 and preserved SIMH media identity by SHA-256.
- Implemented the first real MTBOOT `/L` READ FORWARD: the reel advances 0 -> 2568 and exposes one 2560-byte / 512-word pending data record.
- Implemented the bounded RH20 primary-command path through SBAR/STCR/PBAR/PTCR and the guest-installed channel command list.
- The first 512-word record is deposited into physical `771000..771777`; logout state is written, PCR FULL clears and CMD DONE asserts.
- Extended `KL10_STATE/1` with `KL10_RH20_STATE/2` and nested `KL10_MASSBUS_TAPE_STATE/1`. v0.29 RH20 state is accepted only under its exact legacy schema digest.
- Added authenticated pending-record reconstruction on load; the mounted media SHA must match before execution can resume.
- Preserved instrumented TU45 operator controls (`ONLINE`, `OFFLINE`, `REWIND`, `UNLOAD`) and validated the rich-event sink against Object Queue Fabric v0.8.1.
- Added optional `KL10TerminalMachineV05.cls` integration with Terminal Machine v0.5 `TerminalSession` and `TerminalWatchAlong`.
- Added zero-size PDP-10 byte semantics, IMUL, ordinary-XCT test-family execution and section-zero indirect effective addressing encountered on the real `/L` path.
- Added backing-memory `zeroRange()` for proved-equivalent execution accelerators without converting collapsed loops into fake instruction counts.
- Current schema SHA-256: `3d662969aa66a35bc263fd759a40f274956999b9bec6419c3cb418d4105c9f2f`.
- Validation under ooRexx 5.3.0 r13196: 117 Rexx/class/tool sources compile; the 81-test runtime suite, including legacy v0.29 states, Queue Fabric v0.8.1 and Terminal Machine v0.5 integration, passes.

## v0.29

- Implemented the real post-ENTER `IDPB` boundary. On the supplied v0.28 post-keyboard state, AC5 is CR (`000015`) and AC7 is `440700,,772056`; IDPB increments first to `350700,,772056` and deposits octal `015`.
- Generalized local byte-pointer address resolution so I/X/Y use PDP-10 section-zero effective-address rules. The real following DPB uses pointer `320737,,000000`, resolves through X=`17` plus indirection, and targets instruction `772646`.
- Implemented `DPB` without pointer increment. MTBOOT uses it to self-modify the seven-bit device-select field of its RH20 CONO template: `700201,,000000` becomes `754201,,000000` for device `540`.
- Added bounded RH20 Massbus controller instances for the documented KL device slots `540,544,550,554,560,564,570,574`. Only historically reached controls are implemented: CLR MBC (`002000`) and MASSBUS ENA (`000400`).
- Preserved the explicit-device rule: RH20 controllers are attached deliberately; no tape drive/readiness is invented. With controllers present and no ready Massbus tape unit, MTBOOT itself prints `?BOOT: No ready tape-drive available` and returns to `MTBOOT>`.
- Extended fail-closed `KL10_STATE/1` with zero-or-more `KL10_RH20_STATE/1` records keyed to BUS device codes. BUS/state omissions, extra RH20 records, or schema mismatches are rejected. v0.27/v0.28 DTE-only states are accepted only under their exact previous schema digest.
- Added `tools/MTBootFreezeNoReadyTape.rex`, producing `mtboot.no-ready-tape.prompt` at PC `773466`, ICOUNT `274468`, with all eight RH20 states and the complete guest-generated console transcript.
- Updated the v0.28 ENTER console regression from trace evidence: with IDPB/DPB implemented but no RH20 attached, the same key now executes 102 instructions and stops honestly at `CONO RH20 540,002000`.
- Added real-state IDPB/DPB and no-ready-tape checkpoint regressions. Release validation under ooRexx 5.3.0 r13196: 109/109 Rexx/class/test/tool sources compile and 76/76 runtime regressions pass.

## v0.28

- Added `KL10Console.cls`, a safe host/AI console facade over the existing DTE20 monitor RX/TX path. The facade exposes no CPU, DTE, memory, or I/O-bus getter.
- Added `KL10ConsoleKeyboard` with exact 7-bit `type`, `typeLine`, named key, control-key, and raw-code operations. Optional state tokens reject stale keyboard actions. Non-7-bit input fails closed and BREAK remains an explicit unsupported signal rather than being fabricated as a byte.
- Added immutable `KL10ConsoleSnapshot` and a stream renderer that applies CR/LF/BS/TAB effects while preserving exact DTE output hex. Pending input is reported only as a byte count.
- Added bounded `KL10Console~pump()`. It can stop on operator-wait, output, input delivery, or an exact step limit; a refused CPU instruction is returned as `EXECUTION_REFUSED` with condition evidence rather than swallowed.
- Added `tools/KL10ConsoleDrive.rex`, which applies one keyboard action to an architectural state and can save the resulting stopped state even after an execution refusal.
- Against the supplied `mtboot.prompt` checkpoint, ENTER is delivered through DTE20 and MTBOOT emits an echoed CR before the bounded CPU reaches the next unimplemented instruction, `IDPB` at PC `773446`. This is now an executable regression, not a claimed monitor feature.
- Acceptance follows the supplied checkpoint bytes exactly: its banner is `BOOT V11.0(315)`. The older v0.27 prose contains a longer `31529` string; v0.28 does not silently rewrite the architectural state to match that prose.
- The KL10 architectural state schema remains `KL10_STATE/1` / `dd12699496f2a068969f504c24cbce720bfcfee52d4e45a18eac88e84434e222`; the new console facade adds no hidden machine state.

## v0.27

- Corrected physical-memory existence semantics: sparse EXB deposit extent is no longer mistaken for installed KL10 core. The target has 512 physical 512-word pages (256K words), so undeposited locations such as `777020` are valid zero-filled memory while page `1000` is the first NXM page. The legacy MTBOOT 24/26/33/38-step regressions therefore pass unchanged.
- Implemented bounded KL TOPS-20 section-zero virtual translation behind `CONO PAG,060765`, including EPT/SPT direct/shared/indirect pointer walking, page access protection, CST aging/modification evidence, and explicit NXM probing.
- Implemented `BLKO PAG` as KL `CLRPT` and `MAP` (`257`) as an observe-only pager query. On the authenticated MTBOOT state, `MAP 1,762000` returns `160000,,762000` and leaves CST state unchanged.
- Added the instruction families encountered on the real mapped path: CAI/CAM, AOJ, JUMP, PUSHJ, PUSH, POPJ, ILDB, ADJSP, and ordinary XCT of current-context I/O.
- Implemented `BLKI APR` as KL APRID. The bounded base-KL10 advertisement is `400500,,002001`; no KL10B/extended-addressing facility bit is claimed.
- Added explicit DTE20 (`0200`) attachment and fail-closed `KL10_DTE_STATE/4`. Reset CONI is guest-visible zero while the internal secondary-protocol state is retained.
- Implemented between-instruction DTE secondary `MONON` and `MONO` service. MTBOOT's own 7-bit byte-pointer code produces the frozen output `<CR><LF>BOOT V11.0(31529)<CR><LF><CR><LF>MTBOOT>`.
- Added DTE monitor RX queue state and host `type(text)`. Input delivery follows the KL front-end timing contract: queued input changes only DTE state until post-step service deposits one byte in `DTF11` (`EBR+0450`) and sets `DTMTI` (`EBR+0456`).
- Added `KL10Word` to construct 36-bit values with internal `numeric digits 30`, preventing architectural constants from being rounded by a caller's default Rexx numeric precision.
- Added authenticated checkpoints `mtboot.pre-dte-probe`, `mtboot.pre-map`, and `mtboot.prompt`. `mtboot.prompt` is PC `773466`, ICOUNT `273187`, empty RX, and next proposal `SKIPN 765456`.
- Added focused pager/MAP/APRID/DTE/input/stack/byte-pointer tests. Release validation under ooRexx 5.3.0 r13196: 101/101 Rexx/class/test/tool sources compile and 71/71 runtime regressions pass with the preserved tape/checkpoints supplied.

## v0.26

- Hardened `KL10_STATE/1` from permissive serialization into a fail-closed architectural authenticity contract.
- Added mandatory schema SHA-256 `6ead1c67a795029b094fc3c381b2edfd311146aee374b196227932e0e761aa30`. Missing schema identity, unknown record types, duplicate required records, reordered/missing device fields, incomplete AC sets, and malformed physical-memory shape are rejected.
- Added CPU processor-mode and successful-instruction-count (`ICOUNT`) state. I/O and ordinary instructions increment the counter only after successful architectural completion; refused instructions do not.
- Added bus attachment records and per-device state-schema identities. APR is `KL10_APR_STATE/1`; PAG is `KL10_PAG_STATE/1`. A snapshot whose attached-device set or schema differs from the target machine generation is rejected.
- Added canonical physical-memory SHA-256 (`MEMSHA256`), verified before reconstructing a CPU. A one-word mutation with the original digest is rejected.
- Strengthened the freeze/load invariant to compare memory digest, instruction count, processor mode, bus/device schemas, APR/PAG records, trace, PC and AC state.
- Added destructive `test_state_fail_closed.rex`: omission of one mandatory PAG field, removal of the state schema identity, and unauthenticated physical-memory mutation all fail closed.
- Added read-only `KL10CPU~preview()`: the next instruction is an architectural proposal that can be decoded/resolved without executing it.
- Added generic `KL10Walk.rex` with `step` and `until` predicates for PC, mnemonic, I/O device, I/O function, paging-enable requests and unsupported execution. It contains no MTBOOT-specific addresses.
- The regenerated `mtboot.pre-paging-enable` checkpoint records historical `ICOUNT=125152`; accelerated loop transitions contribute their proven instruction counts to provenance.
- Release validation under ooRexx 5.3.0 r13196: all 82 Rexx/class/test/tool sources compile and all 56 runtime regressions pass with the preserved tape.

## v0.25

- Added versioned `KL10_STATE/1` architectural freeze/load checkpoints. State is serialized as machine state rather than an ooRexx object graph and reconstructs a fresh `KL10CPU` without the original tape.
- Checkpoints include PC, FLAGS/halt state, all eight physical AC blocks, APR state, PAG/AC-block state, and a self-contained physical-memory image. Single-token provenance metadata records machine, source, checkpoint name, and source-tape SHA-256.
- Added state export/import surfaces to `KL10CPU`, `KL10Apr`, `KL10Pag`, `KL10Memory`, and sparse `KL10DepositMemory`.
- Added `test_state_freeze_load.rex`: execute to S, freeze, execute three instructions, load S into a new machine, execute the same three instructions, and require trace plus architectural-state equivalence.
- Added `MTBootFreezePrePaging.rex`. It builds the real preserved MTBOOT state immediately before `CONO PAG,060765`, freezes it as `mtboot.pre-paging-enable`, reloads it into a fresh CPU, and verifies PC/fetch, PAG state, and all 128 physical accumulators before reporting success.
- Added `KL10StateLoad.rex` for tape-free checkpoint inspection and optional stepping.
- Reworked `MTBootStateWalk.rex`: the numeric limit is now visible events rather than a CPU execution ceiling. The already-proven AC1..AC6 relocation loop is mathematically collapsed by the walker only; CPU `step()` semantics remain unchanged.
- The real walker now reports one loop event: 15,360 trips, AC11 `011000->047000`, AC12 `742000->000000`, AC13 `036000->000000`, fall-through at AC7, then follows the fetched JRST once to `771044`. This represents 92,193 actual machine steps while requiring only 38 visible events.
- Release validation under ooRexx 5.3.0 r13196: all 79 Rexx/class/test/tool sources compile and all 54 shipped runtime regressions pass with the preserved tape.

## v0.24

- Continued the verified `BB-H137F-BM` MTBOOT path beyond the v0.23 AOBJN handoff while keeping the preserved tape external to the release ZIP.
- Corrected KL10 PAG DATAO decoding to the documented left-half control format. The real `500600,,000765` word loads current AC block 0, previous AC block 6, and UBR `765000`; a request to select a nonzero live current AC block remains explicit unless that block is actually modeled as current.
- Expanded `KL10CPU` to eight physical accumulator blocks and made ordinary fast-memory references resolve through the PAG current-AC-block selector. Added explicit block accessors for previous-context execution.
- Added the bounded KL10 `PXCT 4` path required by MTBOOT. The executed `MOVEM` data reference is directed to the PAG Previous AC Block, proving that `PXCT 4,[MOVEM 1,3]` writes PAB6 AC3 rather than current AC3. Previous-context ordinary-memory translation remains outside the bounded model.
- Added `DMOVE` (`120` octal) with indexed two-word reads into consecutive accumulators. On the real image, `DMOVE 1,133(16)` loads the vector at `771133/771134`, after which `JRST 1` transfers control into live AC1.
- Added a tape-derived second-loop fast-forward: the proven `MOVEM/AOBJN` loop fills `742000..761777` with `010000,,400000`, allowing regression execution to resume at `771106` without thousands of debug-interpreter steps.
- The new historical acceptance path executes `TLO`, `HRLI`, PAG `DATAO`, three PXCTs, `MOVE`, `TRO`, PAG `CONI`, `ANDI`, `IOR`, `DMOVE`, and `JRST 1`. The next instruction is `CONO PAG,060765`; v0.24 deliberately rejects it because it enables TOPS-20 section-mode virtual translation, which is the next architectural boundary.
- Added focused PAG AC-block, PXCT previous-AC, DMOVE, and real-tape paging-boundary regressions. All 53 shipped runtime tests pass under ooRexx 5.3.0 r13196 when the preserved tape is supplied.

## v0.23

- The preserved `BB-H137F-BM` fixture is now available and verified byte-for-byte by SHA-256 `7248864ad885ee89f4c3e93b0dfa266bfa5e79c136f3cace300480df179780f7` after bzip2 decompression.
- Closed the previously unclaimed historical gap: real MTBOOT step 34 executes `EXCH`, step 35 executes `MOVEM`, steps 36/37 execute `AOS 0,11` / `AOS 0,12` against live AC fast memory, and step 38 executes `SOJG` back to AC1.
- Promoted the complete `350..357` AOS family. The word at E is incremented before signed/zero testing, stored through `KL10AddressSpace`, optionally copied to nonzero AC, and arithmetic carry/overflow flags come from the existing 36-bit ALU path.
- Promoted the complete `360..367` SOJ family. AC is decremented before signed/zero testing; a satisfied condition branches to resolved section-zero E without an operand memory read.
- Promoted `252/253` AOBJP/AOBJN with KL10 independent 18-bit-half increments and sign-tested branching. A dedicated rollover regression prevents accidental KA10-style carry from RH into LH.
- A complete real-tape debug replay establishes the AC-resident loop exit at step 92192 and transfer to `771044`. To keep regression cost bounded, a tape-derived post-loop fast-forward reproduces the exact 036000-iteration memory swap and validates the first real AOBJN site at `771077` (`AC2 777742,,000742 -> 777743,,000743`, branch `771073`).
- Added AOS, SOJ, AOBJ and preserved-tape boundary regressions; `MTBootStateWalk.rex` now admits 38 steps and `MTBootPostLoopAOBJ.rex` exposes the post-loop handoff without replaying ~92k debugger steps.
- Release validation under the supplied ooRexx 5.3.0 r13196 build: 72 Rexx/class/test/tool targets compile with `rexxc`; all 49 shipped runtime regressions pass when the preserved tape is supplied. The manifest contains 78 payload entries and verifies cleanly.

## v0.22

- Promoted `EXCH` (`250` octal) to executable bounded section-zero semantics: the selected accumulator and resolved effective-address word exchange complete 36-bit contents.
- Effective-address calculation and both operand reads occur before either architectural destination is modified.  The E-side write goes through `KL10AddressSpace`, preserving live accumulator-window aliasing.
- Added `test_cpu_exch.rex` covering indexed ordinary memory, AC-to-AC exchange through the fast-memory window, and the self-alias case.  FLAGS remain unchanged and PC advances sequentially.
- Validation under the supplied ooRexx 5.3.0 r13196 build: 66 Rexx class/test/tool targets syntax-check and 27 tape-independent runtime regressions pass, including all 2,006 generated `.LROct` oracle cases.
- The external `BB-H137F-BM` tape fixture was not available to this container because the attempted File Library attachment was rejected upstream as image/media content.  Consequently v0.22 does **not** claim a real-tape 34th-step result; the accepted v0.21 boundary remains the historical handoff point.

## v0.21

- Promoted `BLT` (`251` octal) to executable bounded section-zero semantics.
  The implementation follows the KL10 reference ordering: AC contains the
  `source,,destination` pair, E is the inclusive final destination, the final
  architectural BLT pointer is precomputed in the selected AC, and the transfer
  then proceeds as forward ordinary memory cycles. Indirect/extended-section
  BLT remains outside the current boundary.
- BLT reads and writes every word through `KL10AddressSpace`; there is no bulk
  array/snapshot copy. Dedicated regressions prove AC-window destinations update
  live accumulators, overlapping transfers observe earlier writes, and a BLT
  targeting its own pointer AC preserves the hardware ordering where the later
  memory write can overwrite the precomputed final pointer.
- On the preserved MTBOOT image, `BLT 14,7` consumes
  AC14=`047000,,000001` and copies seven words `047000..047006` directly into
  addresses `000001..000007`, therefore loading live AC1..AC7. The final BLT
  pointer is `047007,,000010`.
- Existing halfword/MOVE/JRST support then carries execution through `040037`
  to `040043`, where `JRST 1` enters the newly loaded fast-memory code. The
  instruction at address `000001` is fetched from AC1 and executed as `MOVE`;
  the next untouched instruction is address `000002`/AC2,
  `250611,,000000` (`EXCH 14,0(11)`).
- Added `test_cpu_blt.rex`, `test_mtboot_thirtythree_steps.rex`, and
  `tools/MTBootThirtyThreeSteps.rex`; `MTBootStateWalk.rex` now walks through
  the 33-instruction boundary and prints BLT source/destination/count/final
  pointer evidence alongside live CPU/address-space/device state.
- Full release validation: 65 Rexx class/test/tool targets compile, 26 local
  runtime regressions pass (including 2,006 generated `.LROct` oracle cases),
  and 17 preserved-tape regressions pass. `BinarySheet.cls` and `OctalBits.cls`
  remain byte-for-byte unchanged.

## v0.20

- Promoted the complete `500..577` octal halfword block to executable bounded
  semantics: all sixteen halfword operations across the four architectural
  forms (memory-to-AC, immediate-to-AC, AC-to-memory, and memory modify/store).
  Left/right selection, preserve/zero/ones/sign-extension behavior, and the
  `M`/`S` destination rules follow the KL10 reference implementation.
- Halfword memory destinations go through `KL10AddressSpace`. Preserve-`M`
  forms read the live destination before merging; zero/ones/sign-extension
  `M` forms can store directly; every `S` form performs a real memory write
  and suppresses the AC destination when AC=0. A dedicated alias regression
  proves `HLLM` to address `000017` merges against and updates live AC17 while
  hidden backing core remains untouched.
- Added `test_cpu_halfword_family.rex`, exercising all 64 opcodes with indexed
  section-zero E, read/write counts, sign-extension cases, AC0 suppression, and
  AC-window destination authority. Arithmetic FLAGS remain unchanged.
- Real MTBOOT now executes twenty-six instructions. `HRRI 14,1` establishes
  AC14=`000000,,000001`; indexed `HRLI 14,7000(16)` resolves E=`047000` from
  AC16 and leaves AC14=`047000,,000001`. The next untouched word is
  `040036 251600,,000007` (`BLT 14,7`).
- Added decode names for the `250..257` control block (`EXCH`, `BLT`, `AOBJP`,
  `AOBJN`, `JRST`, `JFCL`, `XCT`, `MAP`) without widening execution beyond the
  already-admitted plain `JRST`.
- Added `test_mtboot_twentysix_steps.rex` and
  `tools/MTBootTwentySixSteps.rex`; `MTBootStateWalk.rex` now walks the live
  machine through the 26-instruction boundary.
- Full release validation: 62 Rexx class/test/tool targets compile, 25 local
  runtime regressions pass (including 2,006 generated `.LROct` oracle cases),
  and 16 preserved-tape regressions pass. `BinarySheet.cls` and `OctalBits.cls`
  remain byte-for-byte unchanged.

## v0.19

- Promoted the complete `240..246` octal shift/scan block to executable bounded
  semantics: `ASH`, `ROT`, `LSH`, `JFFO`, `ASHC`, `ROTC`, and `LSHC`. Signed
  18-bit count interpretation, rotate modulo behavior, arithmetic-sign
  preservation, AC-pair flow, AC17-to-AC0 pair wrapping, and ASH/ASHC
  `OVR|TRP1` evidence follow the KL10 reference path.
- Promoted the complete `330..337` octal SKIP family: `SKIP`, `SKIPL`, `SKIPE`,
  `SKIPLE`, `SKIPA`, `SKIPGE`, `SKIPN`, and `SKIPG`. Operands are read from
  live `KL10AddressSpace`; AC=0 suppresses the accumulator load while the read
  and skip test still occur.
- Expanded `KL10Pag` from the earlier zero-only boundary into observable KL10
  device state while paging remains disabled. `CONO PAG` now records EBR, pager
  mode bits, and translation-invalidation generation; actual page/TOPS-20
  enable requests still reject until address translation exists. `DATAO PAG`
  implements the bounded UBR-load path used by MTBOOT and rejects unmodeled
  fast-memory-context/previous-section controls.
- Expanded `KL10Apr` with PIA, interrupt-enable, and interrupt-flag state for
  ordinary `CONO`/`CONI` controls while preserving the modeled standalone
  `CONO APR,200000` whole-machine reset boundary.
- Real MTBOOT now executes twenty-four instructions. The live state reaches
  EBR=`047000`, UBR=`047000`, paging still disabled, AC1=`100000,,400047`,
  AC15=`000000,,000047`, AC10=`000000,,777000`, FLAGS=`006000`, and retains
  the earlier `M[047503]=000000,,047007` write. It then branches to `040034`.
- Added `test_cpu_shift_family.rex`, `test_cpu_skip_family.rex`,
  `test_cpu_pag_datao.rex`, `test_mtboot_twentyfour_steps.rex`, and
  `tools/MTBootTwentyFourSteps.rex`. `MTBootStateWalk.rex` now walks up to the
  current 24-instruction boundary and prints live CPU/address-space/bus/APR/PAG
  state as each transition occurs.
- Added decode-only halfword-family names for `500..577`; the next untouched
  real word is `040034 541600,,000001  HRRI 14,1`. No halfword instruction is
  executed in v0.19.
- Full release validation: 59 Rexx class/test/tool targets compile, 24 local
  runtime regressions pass (including 2,006 generated `.LROct` oracle cases),
  and 15 preserved-tape regressions pass. `BinarySheet.cls` and `OctalBits.cls`
  remain byte-for-byte unchanged.

## v0.18

- Promoted the complete PDP-10 MOVE block `200..207` octal to executable family
  semantics: `MOVE`, `MOVEI`, `MOVEM`, `MOVES`, `MOVS`, `MOVSI`, `MOVSM`, and
  `MOVSS`. Direct section-zero indexing is shared through the existing E
  resolver; indirect addressing remains explicitly outside the bounded CPU.
- All MOVE-family memory reads and writes go through `KL10AddressSpace`.
  `MOVEM`/`MOVSM` therefore write live AC-window aliases when E is below `020`,
  while ordinary addresses modify backing memory. `MOVES` and `MOVSS` retain
  the reference modify-cycle write even when the stored value is unchanged;
  AC=0 suppresses their accumulator destination as on the reference CPU.
- Preserved the established MOVSI trace contract while moving MOVSI from its
  old one-off handler into the generic family.
- Added `test_cpu_move_family.rex`, exercising all eight opcodes with indexed E,
  read/write counts, destination semantics, MOVES/MOVSS AC0 suppression, and a
  MOVEM deposit through address `000017` into live AC17.
- Real MTBOOT now executes fourteen instructions: indexed `MOVEI` creates
  AC1=`000000,,047007`, `MOVEM` stores it at `047503`, and the following
  `MOVEI` changes AC1 to `000000,,047000`. FLAGS remain `006000`.
- Added `test_mtboot_fourteen_steps.rex`, `tools/MTBootFourteenSteps.rex`, and
  `tools/MTBootStateWalk.rex`. The latter exposes CPU, address-space, I/O bus, APR and PAG state after every
  admitted real instruction.
- Added decode-only names for the `240..246` shift/scan block so the untouched
  next word is identified as `040016 242040,,777767  LSH`; no shift instruction
  is executed in v0.18.
- All v0.17 I/O-bus, v0.16 arithmetic/Boolean/test, authoritative-memory,
  `.LROct`, and historical tape regressions remain green. `BinarySheet.cls` and
  `OctalBits.cls` remain byte-for-byte unchanged.

## v0.17

- Added public `KL10IOBus` with attachable device objects keyed by decoded PDP-10
  device code. `KL10CPU` now routes admitted I/O instructions through the bus
  instead of embedding APR/PAG transition logic in `step()`.
- APR (`000`) and PAG (`010`) are attached device objects. `cpu~apr` and
  `cpu~pag` resolve through the bus, and all three objects provide `STRING`
  state displays for debugger-style inspection.
- Implemented generic bounded bus semantics for `DATAI`, `DATAO`, `CONO`,
  `CONI`, `CONSZ`, and `CONSO`. `DATAI`/`CONI` writes and `DATAO` reads go
  through the existing authoritative `KL10AddressSpace`, so AC-window aliases,
  live overwrites, and ordinary backing memory remain one state model.
- APR I/O reset now resets peer device state through the bus; PAG CONO/CONI
  semantics live on `KL10Pag`. Existing MTBOOT APR/PAG trace actions and state
  evidence remain compatible.
- Added `test_io_bus_routing.rex`: a synthetic attachable device proves DATAO
  reads current memory, DATAI to `000017` writes AC17, CONI writes ordinary
  backing memory, and CONSO/CONSZ perform mask/skip semantics.
- `BLKI`/`BLKO` remain an explicit boundary pending a real channel/control-word
  model. No TM10/RH10/RH20 tape-device code is guessed or hard-coded.
- No CPU instruction-boundary advance: the preserved MTBOOT path still executes
  through `040012 AND 0,124(16)` and stops before opcode `201` at `040013`.
- All v0.16 arithmetic, 64 Boolean, 64 logical-test, address-space, `.LROct`,
  and historical tape regressions remain green. `BinarySheet.cls` and
  `OctalBits.cls` are byte-for-byte unchanged from recovered v0.16.

## v0.16

- Promoted the regular PDP-10 Boolean block `400..477` octal to executable
  family semantics: all sixteen Boolean functions and all four canonical
  forms per function (AC, immediate, memory destination, both). `404..407` is
  therefore one AND family rather than four unrelated handlers.
- Promoted the complete logical-test block `600..677` octal through one shared
  decoder/executor: right/left masks, direct/swapped memory masks, N/Z/C/O
  modifications, and E/A/N skip conditions. Test instructions do not write
  memory and do not alter arithmetic FLAGS.
- Existing `ANDI` and `TDZ` regressions now run through the generic Boolean/test
  family paths. Memory forms use authoritative `KL10AddressSpace` reads/writes.
- Added exhaustive executable regressions covering all 64 Boolean opcodes and
  all 64 logical-test opcodes, including destination, read/write count, skip,
  mask-side, and FLAGS invariants.
- Real MTBOOT now executes eleven instructions. At `040012`, indexed
  `AND 0,124(16)` resolves E=`040124`, reads `600000,,000000`, leaves AC0 zero
  and FLAGS=`006000`, then stops on untouched opcode `201` at `040013`.
- Added `test_cpu_boolean_family.rex`, `test_cpu_test_family.rex`,
  `test_mtboot_eleven_steps.rex`, and `tools/MTBootElevenSteps.rex`.
- `BinarySheet.cls` and `OctalBits.cls` remain byte-for-byte unchanged.

## v0.15

- Replaced the one-off decode-only SUBI boundary with the complete arithmetic
  opcode families `270..273` (ADD/ADDI/ADDM/ADDB) and `274..277`
  (SUB/SUBI/SUBM/SUBB). The low two opcode bits select memory source,
  immediate, memory destination, or both destinations.
- Added a shared 36-bit arithmetic result path that preserves `.LROct` as a
  pure value object while `KL10CPU` derives KL10 `CRY1`, `CRY0`, `OVR`, and
  `TRP1` flag evidence using Cornwell's ADD/SUB rules.
- Direct section-zero indexing is supported for the new family; indirect
  addressing remains explicitly outside the bounded CPU. Memory destinations
  write through `KL10AddressSpace`, preserving AC-window alias semantics.
- Real MTBOOT now executes ten instructions. `SUBI 16,11` changes
  AC16 `000000,,040011 -> 000000,,040000`, sets FLAGS=`006000`, and stops at
  untouched opcode `404` at `040012`.
- Added `test_cpu_add_sub_family.rex`, `test_mtboot_ten_steps.rex`, and
  `tools/MTBootTenSteps.rex`. All prior v0.14 regressions remain green.
- `BinarySheet.cls` and `OctalBits.cls` remain byte-for-byte unchanged.

## v0.14

- Added executable opcode `254` octal for **plain JRST only** (AC function 0).
  Direct section-zero indexing uses `Y + RH(AC[X])` modulo `2**18`; indirect
  addressing and all other JRST AC subfunctions remain explicitly unsupported.
- JRST performs no operand-memory fetch and leaves the bounded FLAGS word
  unchanged. A synthetic fetch-only regression poisons the index accumulator's
  left half and proves only its right half contributes to the target.
- Real MTBOOT now executes nine admitted instructions. `JSP 16,17` enters the
  AC window; `JRST 0(16)` is then fetched from AC17 through the authoritative
  `KL10AddressSpace` and returns to core at `040011` using
  AC16=`000000,,040011`.
- Added decode-only `SUBI` opcode `275` octal. The untouched next real word is
  `040011 275700,,000011  SUBI 16,11`; it is not executed in v0.14.
- Added `test_cpu_jrst_indexed.rex`, `test_mtboot_nine_steps.rex`, and
  `tools/MTBootNineSteps.rex`.
- The v0.13 live-write, cross-word partial-write, AC-window authority, `.LROct`,
  and all prior historical tape regressions remain unchanged and green.
- `BinarySheet.cls` remains byte-for-byte unchanged.

## v0.13

- Moved section-zero accumulator/fast-memory aliasing out of `KL10CPU` and into
  a new public `KL10AddressSpace`. `KL10CPU~fetch()` and ordinary operand reads
  now ask the address space for the current word; the CPU fetch path has no
  `0..17`-octal special case.
- `KL10CPU~loadImage()` now binds the supplied image memory behind a live
  address space linked to the CPU. Reads/writes to addresses `0..17` octal
  resolve to the currently visible ACs; ordinary addresses resolve to backing
  memory. This leaves register-bank switching as a future CPU-state change,
  not an instruction-fetch rewrite.
- Added authoritative `put`/`deposit` writes. `KL10DepositMemory` mutates its
  sparse store; paged `KL10Memory` keeps copy-on-write overrides of mapped tape
  or zero pages; custom read-only backing objects are supported through an
  address-space overlay. No decoded instruction cache exists.
- Added `KL10AddressSpace~readBits` / `writeBits` with PDP-10 left-to-right bit
  numbering. Cross-word writes perform real read/merge/write operations and
  preserve untouched bits on both affected 36-bit words.
- Added a synthetic authority regression: overwriting live location `004002`
  changes the next decode from TDZ to MOVSI; address `000017` reads/writes AC17
  while contradictory hidden backing core remains untouched; and a six-bit
  write beginning at bit 33 spans two words (`777777,,777777` /
  `000000,,000000` -> `777777,,777772` / `500000,,000000`).
- Added `KL10CPU~string` for direct live-state inspection in DEC octal notation.
- No instruction-boundary advance: real MTBOOT still executes eight admitted
  instructions, then fetches `254016,,000000  JRST 0(16)` from AC17 and stops
  before executing JRST.
- `BinarySheet.cls` remains byte-for-byte unchanged.

## v0.12

- Made `KL10CPU~fetch` obey the PDP-10 section-zero accumulator/fast-memory
  alias: instruction addresses `0..17` octal fetch AC0..AC17 rather than sparse
  core.  `step()` now fetches through that same path.
- Added executable direct/non-indexed `JSP` opcode 265 octal for the bounded
  zero-FLAGS bootstrap state.  It saves `000000,,PC+1` in the selected AC and
  transfers PC to E.  Nonzero FLAGS and other JSP addressing forms remain
  rejected/unmodeled.
- Added a synthetic fetch-only-memory regression proving `JSP 16,17` writes
  AC16 octal, transfers to address 17 octal, and the following instruction is
  fetched from AC17 with no sparse-memory access.
- Real MTBOOT now executes eight admitted instructions: at `040010`,
  `JSP 16,17` saves `000000,,040011` in AC16 and transfers to `000017`.  The
  next word comes from AC17 and decodes as `254016,,000000  JRST 0(16)`.
  JRST remains decode-only.
- Full existing LROct, CPU, tape, EXE, DUMPER, EXB and historical MTBOOT
  regression remains green.
- `BinarySheet.cls` remains byte-for-byte unchanged.

## v0.11

- Corrected the v0.10 conclusion about ooRexx comparison overloading.  Direct
  `::method "="` dispatch works; more importantly, `.LROct` now inherits the
  built-in `Orderable` mixin so its precision-safe `compareTo()` supplies the
  complete comparison-operator family.
- Added `hashCode()` derived from the immutable 36-bit backing string, keeping
  the ooRexx `==`/hash contract valid for Table/Relation-style keyed
  collections.
- Added executable regressions for `=`, `\=`, `<>`, `><`, `==`, `\==`,
  ordering comparisons, and equal-value Table key interchangeability.
- Confirmed separately that defining only `=` does *not* automatically invert
  custom equality for `\=`/`<>`/`><`; the `Orderable` mixin is the correct
  protocol when comparison is driven by `compareTo()`.
- No CPU instruction boundary change: the real MTBOOT path remains halted at
  `040010` before `JSP 16,17`.
- `BinarySheet.cls` remains byte-for-byte unchanged.

## v0.10

- Promoted octal fixture notation into a tested immutable `.LROct` 36-bit word
  algebra in `lib/OctalBits.cls`. The canonical display form is DEC-style
  `LH,,RH`; internal logical state is an exact 36-character binary string.
- Added overloaded ooRexx operators for 36-bit bitwise AND (`&`), OR (`|`),
  XOR (`&&`), NOT (`\`), modulo-`2**36` addition/subtraction, unary two's
  complement, and explicit fixed-width shifts. Right-half carry propagates
  into the left half; 36-bit carry-out is deliberately discarded by the pure
  value operation.
- Added LH/RH accessors plus explicit decimal conversion surfaces. CPU flags,
  overflow, traps, and carry flags remain CPU/ALU semantics and are not stored
  in `.LROct`.
- Added precision-safe string/bitwise `compareTo` and explicit `equals()`.
  Testing proved that ooRexx 5.3.0 does not dispatch infix `=`/`==` to a user
  `::method "="`; object equality therefore stays explicit.
- Added deterministic randomized oracle coverage: 2,006 generated cases for
  add/subtract/AND/OR/XOR/shifts/complement/negation, checked against an
  independent 36-bit integer oracle. This caught the initial `compareTo` bug
  caused by Rexx numeric rounding under default `NUMERIC DIGITS 9`.
- Full existing KL10/MTBOOT regression remains green through the seven-step
  v0.9 execution boundary. `.LROct` is not yet substituted into CPU/memory
  storage; this release validates the value layer before integration.
- `BinarySheet.cls` remains byte-for-byte unchanged.

## v0.9

- Added executable direct `MOVSI` opcode 205 octal. The admitted form loads
  `E,,0` into the selected accumulator and performs no operand memory read.
- Added a poisoned-accumulator semantic guard: AC17 starts at
  `777777777777`; `MOVSI 17,123456` must produce `123456000000`, proving the
  right half is cleared and preventing a fake PC increment or MOVEI-style
  placement from passing.
- Added fetch-only memory guarding for MOVSI.
- The string radix helper independently corrected another proposed hand
  conversion: `205740123456` octal is `42F80A72E` hex; 36-bit all ones remains
  `FFFFFFFFF` hex.
- Real MTBOOT now executes seven admitted instructions and halts at `040010`,
  with AC17=`254016000000`.
- Added decode-only opcode 265 octal as `JSP`; the untouched next preserved
  word is `265700,,000017  JSP 16,17`. JSP execution remains outside the
  bounded CPU.
- `BinarySheet.cls` remains byte-for-byte unchanged.

## v0.8

- Added bounded section-zero indexed effective-address calculation for the
  real `040006 701215,,000000` instruction: X=15 octal contributes the right
  half of AC15, added to Y modulo `2**18`. Indirection remains unsupported.
- Added exactly one PAG control transition: `CONO PAG,E` is executable only
  when the computed effective condition is zero. The condition is not fetched
  from memory.
- `.KL10Pag` now records `conoZeroCount` as model evidence and keeps only the
  bounded observable status word. No page tables, TLBs, UBR, cache, or trap
  machinery were added.
- Added a synthetic indexed-I/O guard: AC15 with right half `600000` makes the
  real instruction compute E=`600000` and reject, proving X is not ignored. A
  nonzero left half with zero right half still yields E=0.
- Updated the earlier PAG regression: post-reset nonzero PAG control remains
  unsupported, replacing the obsolete v0.6 assertion that all PAG CONO was
  unsupported.
- Real MTBOOT now executes six admitted instructions and halts at `040007`.
- Added decode-only `MOVSI` opcode 205 octal so the next preserved word can be
  identified as `205740,,254016  MOVSI 17,254016` without executing it.
- `BinarySheet.cls` remains byte-for-byte unchanged.

## v0.7

- Added executable direct `ANDI` opcode 405 octal. The 18-bit E field is the
  zero-extended immediate operand; no operand memory read occurs.
- Added a nonzero semantic regression: `123456765432 AND 000000600000` octal
  yields `000000600000`, preventing the real zero-state MTBOOT path from being
  passed by a fake PC increment.
- Added fetch-only memory guarding for ANDI, proving the immediate mask is not
  treated as `M[E]`.
- Added `lib/OctalBits.cls` with string-only octal/binary/hex conversions for
  fixtures and diagnostics. It independently corrected proposed hand-written
  hex values: `405640600000` octal is `82E830000` hex and
  `123456765432` octal is `29CBBEB1A` hex.
- Real MTBOOT now executes five admitted instructions and halts at `040006`.
- Exposed, but did not execute, `040006 701215,,000000` as raw I/O fields:
  device PAG, function CONO, indirect 0, X=15 octal, Y=0. Indexed I/O effective
  addressing and PAG control semantics remain the next boundary.
- Retained the v0.6 PAG status model: unknown until the admitted APR reset, then
  exactly zero; no page-table/cache/TLB machinery has been added.
- `BinarySheet.cls` remains byte-for-byte unchanged.

## v0.6

- Added `.KL10Pag` with exactly one readable model datum, `status`. It is
  unknown before the modeled I/O reset and becomes zero after the admitted
  `CONO APR,200000` reset transition. No pager internals are represented.
- Added bounded direct `CONI PAG,E` execution for the reset-state zero status,
  restricted to accumulator-window destinations. E is a destination and is not
  fetched as memory.
- Added an AC15-octal canary/guard-memory regression proving
  `CONI PAG,000015` writes the accumulator alias rather than sparse `M[15]`.
- Added negative boundaries: pre-reset `CONI PAG`, every `CONO PAG`, nonzero
  PAG status, non-AC destinations, and indirect/indexed forms remain
  unsupported.
- Real MTBOOT advances four admitted instructions and halts at `040005`; the
  next word is decoded as `ANDI 15,600000` but not executed.
- `BinarySheet.cls` remains byte-for-byte unchanged.

## v0.5

- Added `.KL10Apr` as a deliberately tiny observable device object with only
  `ioResetCount` and `ioResetDone`; these are model instrumentation, not claims
  about historical APR register layout.
- Added exactly one executable I/O transition: direct/non-indexed
  `CONO APR,200000`. The CONO E field is treated as condition bits and is not
  fetched through memory or the AC window.
- Corrected a proposed decimal translation during implementation:
  `200000` octal is 65536 decimal (`2 ** 16`), not 131072. The source uses the
  power-of-two expression instead of a decimal magic number.
- Real MTBOOT execution now advances a third instruction and halts at `040004`;
  APR reset evidence changes from 0 to 1.
- Added a guard-memory regression proving the CONO E field is not treated as a
  memory operand.
- Added negative regressions: other APR CONO conditions and other devices remain
  unsupported and leave PC/reset evidence unchanged.
- Advanced the unsupported hardware boundary to the real word at `040004`:
  `701240,,000015`, decoded as `CONI PAG,000015` but not executed.
- Retained all v0.4 TDZ/SKIPA AC-window tests and prior tape/EXE/EXB paths.
- `BinarySheet.cls` remains byte-for-byte unchanged.

## v0.4

- Added `SKIPA` opcode 334 octal to the bounded single-step CPU, with direct,
  non-indexed addressing only.
- Corrected PDP-10 accumulator/fast-memory aliasing: memory addresses `0..17`
  octal now resolve to AC0..AC17 at the CPU operand boundary.
- Corrected the v0.3 synthetic TDZ regression, whose address 5 had incorrectly
  been treated as ordinary core.  Ordinary-memory TDZ now uses address 20
  octal; a separate regression proves address 5 reads AC5.
- Added SKIPA regressions for both ordinary memory with a nonzero AC field and
  historical `SKIPA 0,0`, including a contradictory sparse `memory[0]` value
  to prove the CPU reads AC0 instead.
- Real MTBOOT execution now advances two instructions while halting after each:
  `040000 TDZ 0,0 -> 040001`, then `040001 SKIPA 0,0 -> 040003`, skipping the
  word at `040002`.
- Added exact PDP-10 I/O-format decoding without I/O execution.  The first
  unsupported hardware boundary is now exposed as `040003 700200,,200000`,
  `CONO APR,200000`.
- Attempting to step an I/O instruction raises an explicit bounded-CPU error;
  no APR, paging, bus, or device behavior is fabricated.
- `BinarySheet.cls` remains byte-for-byte unchanged from v0.3/v0.2.

## v0.3

- Preserved the v0.2 split between raw tape representation and structured
  TOPS-20 `.EXE` loading.
- Added DUMPER extraction of the real `PS:<NEW-SYSTEM>MTBOOT.EXB.1` from the
  BB-H137F-BM TOPS-20 V7.0 installation tape.
- Added PDP-10 four-8-bit-byte file-stream reconstruction for EXB input.
- Added EXB load-record parsing equivalent to the preserved KL10 simulator
  loader: little-endian byte counts/32-bit addresses, 5-byte 36-bit deposits,
  odd-record padding, and zero-data start-address terminator.
- Real MTBOOT result: 24 data records, 4067 deposited words, addresses
  `040000..054641`, start PC `040000`.
- Added a common `word()` surface to sparse deposit memory for CPU reads.
- Added debugger-style `KL10CPU~step()` with exactly one currently-supported
  instruction: `TDZ` opcode 630 octal in the simple addressing form required by
  MTBOOT's first instruction.
- Added accumulator accessors and corrected accumulator initialization.
- Added non-zero synthetic TDZ semantic regression so the historical fixture
  cannot be passed by a fake PC increment.
- Added real-tape MTBOOT one-step regression: execute `630000,,000000` at
  `040000`, advance to `040001`, remain HALTED, and do not execute the next
  instruction.

## v0.2

- Kept the v0.1 TOPS-20 `.EXE` page-mapped IPL staging path.
- Added a separate generic SIMH/PDP-10 raw tape-file depositor.
- Fixed wide-number precision before conversion.
- Added correct SIMH odd-record padding, error flag, tape mark and EOM handling.
- Removed fixed 256K-word deposit storage and silent truncation.
- Raw loader deliberately does not invent PC=0.
- Added positive detection that BB-H137F-BM tape file 0 is a TOPS-20 `.EXE`
  directory (`001776,,000017`), not a raw bootstrap instruction stream.

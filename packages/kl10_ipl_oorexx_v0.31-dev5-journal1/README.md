# KL10 IPL ooRexx v0.31-dev5-journal1

A deliberately bounded TOPS-20/KL10 bootstrap experiment built on
BinarySheet v0.4 and tested with the preserved `BB-H137F-BM` TOPS-20 V7.0
installation tape.

It is a deliberately bounded KL10 execution model and it does **not** claim
TOPS-20 has booted. Version 0.30 moves the real MTBOOT `/L` path through RH20,
TM03 and a mounted TU45 far enough to perform the first genuine READ FORWARD.
The authenticated BB-H137F-BM reel advances from byte 0 to 2568; RH20 executes
the guest-installed channel program and deposits all 512 36-bit words into
physical `771000..771777`, writes logout state and asserts CMD DONE. The moved
reel and pending record are now part of the fail-closed machine state.


## Hot journal / live recovery

`KL10Journal.cls` adds a long-lived development mode on top of the ordinary emulator.
It does not replace `KL10_STATE/1`: durable state remains the cold restart/export format,
while State-of-the-Nation checkpoints are pointers into retained journal history.

An instruction can therefore be run transactionally:

```text
before-instruction -> execute -> commit
                   \-> refuse -> rewind -> install trial OPooo method -> retry
```

`KL10Memory` journals only changed write-overlay words. CPU registers and stateful devices
are separate participants. Rewinding machine state does not rewind object-scope code, so a
trial instruction method can be inserted and tested against the exact pre-fault historical
state without reloading the emulator. Unsupported opcodes expose a bounded `OPooo` extension
seam; already implemented opcodes continue to use their fixed architectural implementations.

The hot journal and cold checkpoint paths are intentionally separate. `saveCompressed()` /
`loadCompressed()` provide native zlib cold checkpoints using `lib/KL10Deflate.cls`; the codec
uses `::options digits 30` so Adler-32 remains correct under ooRexx numeric arithmetic.


## Architectural freeze/load

`KL10_STATE/1` is an explicit architectural state format, not ooRexx object
serialization. v0.26 makes the format fail closed.

Every file must contain the exact schema digest:

```text
SCHEMA 3d662969aa66a35bc263fd759a40f274956999b9bec6419c3cb418d4105c9f2f
```

The canonical required schema is:

```text
KL10_STATE/1
CPU: pc, flags, halted, mode, icount
AC: 8 x 16 physical accumulator words
BUS: code, name, device-state schema
APR: resetCount, resetDone, aprIrq, irqEnable, irqFlags
PAG: statusWord, conoZeroCount, conoCount, ebPtr, ubPtr,
     pageEnabled, tops20Page, tlbFlushCount, dataoCount, lastDatao,
     currentAcBlock, previousAcBlock, previousContextSection
DTE (when attached): statusInternal, count, resetCount, servicePending,
     monitorMode, serviceCount, txHex, rxHex
RH20 (zero or more): device code, statusWord, preparation, resetCount,
     massbusEnabled, SBAR/STCR/PBAR/PTCR/IVIR command-register state
MBTAPE (zero or more): RH20/unit, TM03/TU45 status, authenticated media SHA,
     byte position, file/mark position, pending record descriptor
MEM: mapped pages, exactly 512 36-bit words/page, SHA-256
```

Changing any required architectural field requires a new schema identity.
A snapshot omitting a field is not repaired with a default. It is rejected.
Unknown record types are also rejected.

Attached devices are part of the snapshot contract. Each bus record names the
device code, device name, and its state schema (`KL10_APR_STATE/1`,
`KL10_PAG_STATE/1`; an attached DTE is `KL10_DTE_STATE/4`; current RH20
state is `KL10_RH20_STATE/2`, with v0.29's `KL10_RH20_STATE/1` accepted only
under its exact legacy machine-schema digest). A state whose attachment set or
device schema differs
from the machine generation being loaded is rejected.

Physical memory is serialized canonically as PAGE/WORD records. `MEMSHA256`
covers that canonical image and is verified before constructing the target
CPU. The implementation currently uses the host `sha256sum` utility for this
integrity check.

The authenticated checkpoint chain now exposes four useful execution objects:

```text
mtboot.pre-paging-enable  PC=000001  ICOUNT=125152
mtboot.pre-dte-probe      PC=772431  ICOUNT=272638
mtboot.pre-map            PC=772512  ICOUNT=273068
mtboot.prompt             PC=773466  ICOUNT=273187
```

`mtboot.prompt` contains the complete DTE output queue:

```text
<CR><LF>BOOT V11.0(315)<CR><LF><CR><LF>MTBOOT>
```

and an empty DTE RX queue. `DTF11` (`EBR+0450`) and `DTMTI` (`EBR+0456`) are
both zero. The next architectural proposal is `SKIPN 765456`, so loading the
checkpoint materializes the KL10 at the first monitor-input wait without
reading the tape or replaying MTBOOT.

`tools/AttachDteState.rex` is an explicit state transition. A checkpoint without
DTE state does not silently acquire a device during load. `tools/MTBootFreezePreMap.rex`
and `tools/MTBootFreezePrompt.rex` derive and round-trip the later named states.

The determinism invariant is executable:

```text
run N -> freeze S -> run K -> T1
new machine; load S -> run K -> T2
T1 == T2
```

The regression compares trace, PC, all current ACs, APR/PAG records, bus
attachment schemas, processor mode, instruction count, and the physical-memory
digest. Separate destructive tests remove a required PAG field and alter one
physical word without updating the digest; both loads must fail.


## State walker

`KL10CPU~preview()` exposes the proposed next architectural action without
mutating PC, ACs, devices, or instruction count. `tools/KL10Walk.rex` consumes
that observation surface:

```text
rexx tools/KL10Walk.rex state.kl10state step 3
rexx tools/KL10Walk.rex state.kl10state until pc=771112
rexx tools/KL10Walk.rex state.kl10state until mnemonic=XCT
rexx tools/KL10Walk.rex state.kl10state until io.device=PAG
rexx tools/KL10Walk.rex state.kl10state until io.function=CONO
rexx tools/KL10Walk.rex state.kl10state until paging.enable-request
rexx tools/KL10Walk.rex state.kl10state until unsupported
```

Predicates are architectural observations; no MTBOOT address knowledge is
embedded in the generic walker. Against `mtboot.pre-paging-enable`,
`until paging.enable-request` matches after zero executed steps and reports
`CONO PAG,060765` as the pending proposal.

`MTBootStateWalk.rex` remains the historical tape presentation path. It counts
*visible events*, not permitted CPU instructions.
The first 37 machine steps remain verbose archaeology. At the proven AC6 SOJG
back-edge the walker collapses the relocation loop as a presentation
acceleration, leaving `KL10CPU~step()` untouched:

```text
AC-loop trips=15360 AC11 011000->047000 AC12 742000->000000 AC13 036000->000000
fallthrough PC=000007 254010,,772044 JRST
panel-switch JRST -> 771044
visible=38 machine-steps=92193
```



## TOPS-20 pager and MAP

`CONO PAG,060765` now enables the bounded KL TOPS-20 section-zero pager. The
address-space walker follows the real EPT/SPT/page-pointer chain on every mapped
reference; no TLB cache is hidden behind the evidence surface. The first mapped
instruction at VA `772350` resolves through:

```text
section pointer @ 765540 = 220000,,000000
SPT base                    = 765760
page-map page               = 000766
page pointer @ 766772       = 124000,,000772
physical address            = 772350
```

`MAP 1,762000` uses the same walker in observe-only mode. It returns
`160000,,762000`: a valid EXEC mapping, modified and writable, to physical
address `762000`. MAP does not age/modify the CST and performs no ordinary
operand memory reference.

The bootstrap sizing probe also distinguishes installed physical core from
EXB deposit extent. The preserved machine has 512 physical 512-word pages
(256K 36-bit words); undeposited installed core reads as zero, while a mapped
reference to page `1000` raises APR NXM. This distinction is why the original
24/26/33/38-step archaeology regressions continue to pass unchanged.

## Host console and keyboard facade

`KL10Console.cls` adds a deliberately narrow operator/AI surface over the real
DTE20 monitor path. It does **not** add a command interpreter to the emulator and
it does not expose the CPU, DTE object, memory, or I/O bus. Keyboard operations
only enqueue 7-bit bytes into the existing DTE RX queue; guest-visible delivery
still occurs later through `KL10IOBus~advance` between CPU instructions.

The main objects are:

```text
KL10Console
    snapshot()              immutable console observation
    stateToken()            stale-action token
    inputReady()
    guestWaitingForInput()
    pump(limit, mode)        execute the bounded CPU, fail closed
    keyboard()

KL10ConsoleKeyboard
    type(text [, token])
    typeLine(text [, token])
    press(ENTER|LF|TAB|BS|ESC|SPACE|RUBOUT|NUL [, token])
    control(C [, token])
    sendCode(0..127 [, token])
```

`BREAK` is intentionally refused because the current DTE model has no separate
break/signal path; the facade does not invent one by turning BREAK into an
arbitrary character. Non-7-bit input is likewise rejected instead of being
silently folded modulo 128.

The snapshot is stream-oriented. `KL10ConsoleRenderer` applies CR, LF, BS and
TAB cursor effects to the DTE output bytes and preserves the exact output bytes
separately as hexadecimal evidence. Pending keyboard contents are exposed only
as a byte count, not as the queued text itself.

The supplied `mtboot.prompt` state is immediately operable through the facade.
An ENTER key is delivered and MTBOOT echoes CR. With the current bounded CPU,
execution then stops honestly at `773446` on the next unimplemented `IDPB`
instruction. `pump()` reports `EXECUTION_REFUSED` and preserves that stopped
architectural state rather than pretending the command completed.

`tools/KL10ConsoleDrive.rex` can apply one keyboard action to a saved state,
optionally advance the machine, and save the resulting state even when the CPU
reaches a bounded execution refusal. Run it from the `tools/` directory, matching
the existing relative `::requires` convention.

Examples:

```text
cd tools
rexx KL10ConsoleDrive.rex mtboot.prompt next.state KEY ENTER 200 WAIT
rexx KL10ConsoleDrive.rex mtboot.prompt next.state TYPE N 4 STEPS
rexx KL10ConsoleDrive.rex mtboot.prompt next.state CTRL C 20 OUTPUT
```

An AI-facing caller should normally retain the `stateToken` from the last
snapshot and supply it with the next keyboard operation. A stale token returns
`STALE_STATE` without changing DTE input state.

## DTE20 secondary monitor protocol

Device `0200` is attached only through explicit `AttachDteState.rex`. Reset
CONI is guest-visible zero; the internal secondary-protocol bit remains device
state. `MONON` and `MONO` are serviced between CPU instructions by
`KL10IOBus~advance`, never inside CPU opcode semantics.

DTE output is retained as hexadecimal bytes (`txHex`) on the device and is part
of `KL10_DTE_STATE/4`. DTE host input uses `dte~type(text)` to enqueue 7-bit
bytes in `rxHex`. Enqueueing does not touch guest memory. During a later
post-instruction device service, if monitor mode is active and `DTMTI` is clear,
one byte is deposited in `DTF11` and `DTMTI` is set to all ones. This makes
host input, guest observation, and execution timing independently testable.

`KL10Word` centralizes 36-bit constant construction under `numeric digits 30`.
Device code uses it for values such as APRID bits and the 36-bit all-ones
completion word, preventing default ooRexx numeric precision from silently
rounding architectural constants.


## Keyboard ENTER, byte pointers, and RH20 discovery

The v0.28 console façade remains the host/terminal seam. From
`mtboot.prompt`, `keyboard~press("ENTER", token)` queues exactly one CR byte;
guest execution remains separate.

The first previously unsupported instruction was the real MTBOOT operation:

```text
PC 773446
136240,,000007  IDPB
AC5 = 000015
AC7 = 440700,,772056
```

IDPB increments the 7-bit byte pointer before depositing. The regression
requires AC7 to become `350700,,772056` and the deposited byte to be octal
`015`, proving that ENTER is not being transformed into a guessed monitor
command.

The later `DPB 775160` uses a real indexed/indirect local byte pointer
`320737,,000000`. Its resolved target is instruction `772646`: MTBOOT is
self-modifying the seven-bit device-select field of its RH20 CONO template.
The first patch changes:

```text
700201,,000000
    ->
754201,,000000
```

which selects RH20 device `540`. Subsequent passes select the documented RH20
slot sequence `540,544,550,554,560,564,570,574`.

The bounded `.KL10Rh20` currently implements only operations actually reached
by MTBOOT: `CLR MBC` (`CONO ...,002000`) and `MASSBUS ENA`
(`CONO ...,000400`). No drive-ready status is fabricated. With controllers
present but no Massbus tape unit attached, MTBOOT itself emits:

```text
?BOOT: No ready tape-drive available
```

and returns to its normal monitor-input wait.

The resulting authenticated checkpoint is:

```text
checkpoint = mtboot.no-ready-tape.prompt
PC         = 773466
ICOUNT     = 274468
next       = 336000,,765456  SKIPN
RH20       = 540,544,550,554,560,564,570,574
```

Its DTE transcript ends:

```text
MTBOOT>

  ?BOOT: No ready tape-drive available

MTBOOT>
```

RH20 attachment is explicit and freezeable. v0.29's `KL10_STATE/1` schema
therefore contains one `RH20` state record for every RH20 present on the BUS;
load fails closed if BUS and RH20 state records disagree. v0.27/v0.28 DTE-only
states remain accepted under their exact legacy schema digest.



## v0.30: mounted TU45 and first RH20 channel read

The operator command is delivered through the real terminal path:

```text
MTBOOT>/L
```

MTBOOT probes RH20/TM03/TU45 state and eventually writes the RH20 command
registers. The first transport command reached is TM03 function `071`
(READ FORWARD). The preserved SIMH reel then moves:

```text
media SHA-256  7248864ad885ee89f4c3e93b0dfa266bfa5e79c136f3cace300480df179780f7
position       0 -> 2568
record         DATA, 2560 bytes, 512 x 36-bit words
```

The guest-installed RH20 channel program points at physical `771000` with a
512-word transfer count. v0.30 executes that bounded channel command and
requires:

```text
tape word 0      = memory 771000
tape word 511    = memory 771777
logout updated
PCR FULL cleared
CMD DONE asserted
```

The first transferred word is `001776,,000017`.

`KL10MassbusTape` now carries explicit mounted/online/write-lock state, TM03
registers, reel position, file/mark position, pending-record reconstruction and
operator controls. Media restore authenticates the reel by SHA-256 before
reconstructing a pending record.

The TU45 operator facade exposes instrumentable `ONLINE`, `OFFLINE`, `REWIND`
and `UNLOAD` actions with stale-state tokens and before/after snapshots.
`KL10TapeOperatorQueueFabricSink` is optional and has been validated unchanged
against Object Queue Fabric v0.8.1.

## Terminal Machine v0.5 bridge

`KL10TerminalMachineV05.cls` is an optional adapter into the generic
`TerminalSession`/`TerminalWatchAlong` architecture. It converts the safe
`KL10Console` snapshot into a terminal-neutral `TerminalSnapshot` and forwards
keyboard actions through the DTE20 facade. It has no CPU, DTE, memory or bus
getter.

This keeps the layering explicit:

```text
TerminalSession / WatchAlong
          |
KL10TerminalModelV05
          |
     KL10Console
          |
        DTE20
          |
        KL10
```

The bridge advertises `CHARACTER_STREAM`, `CHARACTER_INPUT`, `CONTROL_KEYS`,
`STALE_ACTION_TOKEN` and `KL10_DTE20`.


## v0.31-dev execution runner

`KL10Execution.cls` turns accelerated execution into an explicit object rather
than hiding it inside `cpu~step`. Ordinary `KL10CPU~step` remains the reference
single-instruction semantic path.

`KL10ExecutionRunner` currently contains two proved-equivalent MTBOOT
accelerators:

1. The three-instruction memory-clear loop at `774670..774672`. For an
   inclusive range of N words it performs the identical memory transformation,
   leaves AC1 at the final address, falls through to `774673`, and advances
   architectural ICOUNT by exactly `3*N-1`.

2. The steady 32-instruction physical-memory probe cycle rooted at `774542`.
   The accelerator fingerprints the routine, validates stack/scratch state,
   executes the same two observable PAG CLRPT generations, and accepts only a
   MAP result whose right half is the candidate page and whose `100000`
   mapping-valid bit is asserted. Other MAP status bits are allowed because
   MTBOOT itself clears them with `TLZ 1,777760` before they can affect the
   cycle.

The probe accelerator deliberately refuses candidate `777000`. The real
instruction stream must execute the 36-bit `ADDI 13,001000`, observe the carry
to `000001,,000000`, and take the historical exit into the clear phase.

`tools/KL10Run.rex` runs a frozen state through the runner and freezes the
result on normal completion. Accelerators reduce host work only; they do not
reduce architectural instruction counts.

Observed from the authenticated post-first-read checkpoint:

```text
30 memory-probe cycles were reached before the 777000 carry boundary.
The real 777000 cycle then reaches the clear loop at 774670.

CLEAR #1: 000020..000777  -> 1,487 historical instructions
CLEAR #2: 001000..001777  -> 1,535 historical instructions
```

The development runner executed 5,119 historical instructions in 1,200 host
work units with 31 proved collapses before continuing into the next MTBOOT
memory-preparation phase.


## v0.31-dev2 fast freeze/persistence

`KL10State~freeze(cpu[, metadata])` now materializes a detached
`.KL10FrozenState` in memory. The frozen object owns its encoded state bytes,
memory digest, copied metadata, schema identity and record/byte counts.

Persistence is separate:

```rexx
frozen = state~freeze(cpu, meta)

/* Live CPU may now continue or change. */
frozen~save("checkpoint-a.kl10state")
frozen~save("checkpoint-b.kl10state")
```

`KL10State~save(cpu,path[,metadata])` remains as a compatibility wrapper around
`freeze()` followed by `frozen~save(path)`.

The writer no longer calls `lineout()` once per architectural record. State
records are collected in memory, joined with `Array~makeString("L","0a"x)`,
and the final encoded state is persisted with one `charout()`.

The load-side canonical memory verifier uses the same in-memory join rather
than replaying every PAGE/WORD record through a temporary `lineout()` stream.

Measured on the 3,682,814-byte authenticated first-read checkpoint under the
supplied ooRexx 5.3.0 r13196 debug runtime:

```text
old save(cpu,path)             5.23 s

new freeze(cpu)                ~6 s  (state construction + canonical digest)
frozen~save(path), first       0.0005-0.005 s
frozen~save(path), repeated    0.007-0.011 s

old large-state load/verify    ~17.0 s
new large-state load/verify    ~5.8 s
```

The critical semantic difference is not merely speed: a freeze is now an
execution artifact independent of the live machine. Mutating CPU memory or the
caller metadata after `freeze()` does not alter the frozen bytes subsequently
written to disk.

## Architecture boundary

```text
BinarySheet                 binary/bit primitives only
KL10TapeRaw / MTBoot        SIMH, DUMPER, EXB meaning
KL10CPU                     registers + bounded instruction semantics
KL10IOBus                   decoded I/O routing + device attachment
KL10Apr / KL10Pag           bus-attached observable device boundaries
KL10AddressSpace            authoritative address resolution + live writes
KL10Memory / DepositMemory  backing storage
lib/OctalBits.cls           radix helpers + immutable 36-bit `.LROct` algebra
```

`lib/BinarySheet.cls` is unchanged and still knows nothing about SIMH,
DUMPER, EXB, KL10, APR, PAG or TOPS-20.

## Authoritative address space

`KL10CPU~loadImage()` now places the supplied image/backing memory behind a
live `KL10AddressSpace` linked to the CPU. The CPU does not special-case the
accumulator window when fetching instructions or ordinary operands:

```text
CPU fetch / operand read
        |
        v
KL10AddressSpace~word(address)
        |
        +-- 000000..000017 -> current AC0..AC17
        |
        +-- other address  -> live backing memory
```

The same address space owns writes. `put(000017, value)` changes AC17, while
`put(004002, value)` changes the stored word at `004002`. A following fetch
therefore decodes whatever 36 bits are currently present; there is no separate
or cached program representation to become stale. Official sparse
`KL10DepositMemory` writes mutate the backing store, and paged `KL10Memory`
uses copy-on-write overrides for mapped tape/zero pages.

For packed/overlapping state, `readBits(address, bitOffset, width)` and
`writeBits(address, bitOffset, bitString)` use PDP-10 bit numbering (offset 0
is the MSB of a 36-bit word) and span successive words when necessary. A write
therefore reads each affected word, replaces only the selected bits, and writes
the merged word back. The regression intentionally writes six bits beginning
at bit 33, crossing a word boundary and proving both neighboring words retain
their untouched bits.

`KL10CPU~string` exposes the live register state directly in DEC octal notation
for debugger-style inspection.

## I/O bus boundary

`KL10CPU` owns one public `KL10IOBus`. APR (`000`) and PAG (`010`) are attached
objects and `cpu~apr` / `cpu~pag` resolve through that bus. The decoder still
extracts the real PDP-10 I/O fields from the 36-bit instruction, but execution
now follows one generic path:

```text
36-bit I/O instruction
        |
        v
KL10CPU decode + section-zero E resolution
        |
        v
KL10IOBus -- device code --> attached device object
        |
        +-- CONO: device control condition E
        +-- CONI: device status -> KL10AddressSpace~put(E, word)
        +-- DATAO: KL10AddressSpace~word(E) -> device
        +-- DATAI: device word -> KL10AddressSpace~put(E, word)
        +-- CONSZ/CONSO: device status masked by E -> optional skip
```

This deliberately preserves the live-memory rule. A synthetic `DATAI` to
address `000017` writes AC17 because that address is the current fast-memory
window; a synthetic `CONI` to `004001` modifies ordinary backing memory. There
is no I/O-private memory bank. `DATAO` likewise reads the current word from the
same address space used by instruction fetch and ordinary operands.

APR reset is now a device operation: `CONO APR,200000` records the APR reset and
asks the bus to reset other attached devices, which establishes the bounded PAG
status used by the existing MTBOOT `CONI PAG,15`. `CONO PAG,0(15)` is routed to
the PAG object after the CPU resolves the indexed section-zero E value.

`BLKI` and `BLKO` are decoded but explicitly rejected. Their channel/control-
word and DMA semantics will be added with an RH/DF-style channel object rather
than approximated. No tape-controller device code is hard-coded in v0.24.

`STRING` methods expose bus/device state directly, for example:

```text
KL10IOBus [devices=000:APR,010:PAG]
KL10Apr [device=000 resetCount=1 resetDone=1 PIA=000000 irqEnable=000000 irqFlags=000000]
KL10Pag [device=010 status=000047 EBR=047000 UBR=047000 pageEnable=0 t20Page=0 conoCount=2 conoZeroCount=1 dataoCount=1 tlbFlushCount=4]
```

`tools/MTBootStateWalk.rex` combines those views while stepping the real MTBOOT
fixture. After each admitted instruction it prints the fetched word/source,
resolved E when present, the full live CPU register/FLAGS/PC state, the address
space, and APR/PAG/bus state for I/O instructions. Memory-destination MOVE
operations additionally show the word written. This is a state inspection tool,
not a separate execution model.

## Real MTBOOT load state

The tape adapter extracts `PS:<NEW-SYSTEM>MTBOOT.EXB.1` and reproduces the
preserved EXB loader grammar:

```text
DUMPER data records: 11
padded DUMPER words: 5632
EXB data records:    24
EXB words deposited: 4067
load range:          040000 .. 054641
start PC:            040000
```

## CPU boundary

`KL10CPU~step()` is debugger-style: one admitted instruction executes and the
CPU becomes HALTED again. Unsupported instructions, addressing modes and
hardware state raise rather than being approximated. The address space remains
authoritative for every operand read and memory destination.

Executable families/switches added through this release:

- `200..207` octal — complete MOVE/MOVS source/destination family;
- `250` octal — `EXCH`, with indexed section-zero E and authoritative AC-window aliasing;
- `252..253` octal — KL10 `AOBJP/AOBJN`, incrementing the two 18-bit halves independently before sign-tested branch;
- `350..357` octal — complete `AOS` increment-memory-and-skip family;
- `360..367` octal — complete `SOJ` decrement-AC-and-jump family;
- `240..246` octal — `ASH`, `ROT`, `LSH`, `JFFO`, `ASHC`, `ROTC`, `LSHC`;
- `270..277` octal — complete ADD/SUB memory/immediate/M/B families;
- `330..337` octal — complete signed/zero SKIP family;
- `400..477` octal — all sixteen PDP-10 Boolean functions, each with the four
  canonical destination forms (for example `404..407` = `AND/ANDI/ANDM/ANDB`);
- `500..577` octal — all sixteen PDP-10 halfword functions, each with memory,
  immediate, memory-destination and modify/store forms;
- `600..677` octal — the complete logical-test matrix: right/left masks,
  direct/swapped-memory masks, N/Z/C/O modifications, and E/A/N skip tests;
- Boolean/test instructions leave arithmetic FLAGS unchanged; test instructions
  never write memory; every memory form reads through `KL10AddressSpace`;
- APR/PAG, `JSP`, and plain `JRST` boundaries remain green; `250..257` retain
  decode names, with `EXCH`, `BLT`, `AOBJP`, `AOBJN`, and plain `JRST` now executable inside their
  explicitly bounded section-zero forms.

The Boolean implementation is family-driven rather than a collection of one-off
opcodes. `ANDI` and `TDZ` now execute through those generic family paths while
their older semantic regressions remain unchanged.

## ooRexx comparison protocol correction

`.LROct` now inherits the built-in `Orderable` mixin and implements a
precision-safe `compareTo()`.  ooRexx therefore dispatches the complete value
comparison family (`=`, `\=`, `<>`, `><`, `==`, `\==`, `<`, `<=`, `>`,
`>=`, and their strict relatives) through `compareTo()`.  The earlier v0.10
claim that infix `=` could not be overloaded was incorrect: the real issue was
that the class had a `compareTo()` method without inheriting `Orderable`.

Because `==` is now value equality, `.LROct~hashCode` delegates to the immutable
36-bit backing string so separately-created equal values are interchangeable
keys in hash-based collections.

## 36-bit `.LROct` algebra

`Oct("123456,,765432")` now constructs an immutable 36-bit `.LROct` value.
The object stores exactly 36 binary characters internally and renders in DEC
left/right notation. Bitwise operations therefore never need decimal
conversion.

Examples:

```rexx
masked = Oct("123456,,765432") & Oct("000000,,600000")
wrapped = Oct("777777,,777777") + Oct("000000,,000001")
carry18 = Oct("000000,,777777") + Oct("000000,,000001")

/* masked  = 000000,,600000 */
/* wrapped = 000000,,000000 */
/* carry18 = 000001,,000000 */
```

Supported value operations in v0.15 are `&`, `|`, `&&`, unary `\`, `+`,
`-`, unary minus, `shl()`, and `shr()`. Arithmetic wraps modulo `2**36`.
CPU carry/overflow flags are intentionally **not** properties of `.LROct`;
v0.15 keeps that separation and derives carry/overflow evidence in `KL10CPU`
when executing arithmetic instructions.

Three ooRexx-specific findings are locked by execution tests:

1. a direct `::method "="` does override infix `=` when the custom object is
   the receiver/left operand;
2. `compareTo()` drives the complete comparison-operator family when the class
   inherits ooRexx's built-in `Orderable` mixin. Defining only `=` does not
   automatically make `\=`/`<>`/`><` invert that custom equality;
3. comparing 36-character `0/1` strings using Rexx numeric `<` can round under
   default `NUMERIC DIGITS 9`; `.LROct~compareTo()` therefore scans bits from
   most-significant to least-significant instead.

A deterministic generated regression checks 2,006 arithmetic/bitwise/shift
cases against an independent 36-bit integer oracle, with separate Orderable
coverage for equality, ordering, and hash-key interchangeability. The existing
MTBOOT CPU remains numerically stored in v0.15; `.LROct` is used at selected
semantic boundaries and in fixtures, but memory/register storage has not been
wholesale converted to objects.

## Precision-safe octal fixtures

`lib/OctalBits.cls` adds string-only `Oct2Bin`, `Bin2Oct`, `Oct2Hex`, and
`Hex2Oct` helpers. They avoid routing large fixture constants through decimal
conversion and therefore work beyond 36 bits.

The helper caught two proposed hand conversions during v0.7 work:

```text
405640600000 octal = 82E830000 hex
123456765432 octal = 29CBBEB1A hex
```

The CPU itself still stores 36-bit words numerically with explicit
`numeric digits`; these helpers are for notation, diagnostics and fixtures.

## Real twenty-six-step sequence

```text
040000 : 630000,,000000   TDZ   0,0          -> 040001
040001 : 334000,,000000   SKIPA 0,0          -> 040003
040003 : 700200,,200000   CONO APR,200000    -> 040004
040004 : 701240,,000015   CONI PAG,000015    -> 040005
040005 : 405640,,600000   ANDI 15,600000     -> 040006
040006 : 701215,,000000   CONO PAG,0(15)     -> 040007
040007 : 205740,,254016   MOVSI 17,254016     -> 040010
040010 : 265700,,000017   JSP   16,17         -> 000017
000017 : 254016,,000000   JRST  0(16)         -> 040011  fetched from AC17
040011 : 275700,,000011   SUBI  16,11         -> 040012  AC16=000000,,040000 FLAGS=006000
040012 : 404016,,000124   AND   0,124(16)     -> 040013  E=040124 M=600000,,000000
040013 : 201056,,007007   MOVEI 1,7007(16)   -> 040014  AC1=000000,,047007
040014 : 202056,,007503   MOVEM 1,7503(16)   -> 040015  M[047503]=000000,,047007
040015 : 201056,,007000   MOVEI 1,7000(16)   -> 040016  AC1=000000,,047000
040016 : 242040,,777767   LSH   1,777767      -> 040017  AC1=000000,,000047
040017 : 434640,,000001   IOR   15,1          -> 040020  AC15=000000,,000047
040020 : 701215,,000000   CONO  PAG,0(15)     -> 040021  E=000047 EBR=047000
040021 : 670056,,000125   TDO   1,125(16)     -> 040022  AC1=100000,,400047
040022 : 701140,,000001   DATAO PAG,1         -> 040023  UBR=047000
040023 : 700200,,022000   CONO  APR,022000    -> 040024
040024 : 201400,,777000   MOVEI 10,777000     -> 040025  AC10=000000,,777000
040025 : 330010,,000020   SKIP  0,20(10)      -> 040026  E=777020 M=0
040026 : 700340,,002000   CONSO APR,002000    -> 040027  status&mask=0
040027 : 254016,,000034   JRST  34(16)        -> 040034
040034 : 541600,,000001   HRRI  14,1          -> 040035  AC14=000000,,000001
040035 : 505616,,007000   HRLI  14,7000(16)   -> 040036  E=047000 AC14=047000,,000001
040036 : 251600,,000007   BLT   14,7                      NOT executed
```

The state is intentionally inspectable at every step. At the current stop:

```text
FLAGS = 006000
AC1   = 100000,,400047
AC10  = 000000,,777000
AC14  = 047000,,000001
AC15  = 000000,,000047
AC16  = 000000,,040000
AC17  = 254016,,000000
PAG   = EBR 047000, UBR 047000, pageEnable 0, t20Page 0
APR   = PIA 0, irqEnable 0, irqFlags 0
```

The real path therefore demonstrates CPU, memory, I/O-bus and device state as
one evolving machine rather than separate reconstructed traces.

## JRST trampoline boundary

The word manufactured in AC17 by the preceding MOVSI is:

```text
254016,,000000   JRST 0(16)
```

For plain JRST (AC function 0), v0.14 uses the same bounded section-zero
18-bit effective-address rule already exercised by indexed I/O: `E = Y +
RH(AC[X])` modulo `2**18`.  The real path has AC16=`000000,,040011`, so the
instruction fetched from AC17 computes E=`040011` and transfers PC there.
JRST does not fetch a memory operand and does not alter FLAGS.

A synthetic guard poisons the left half of AC3 and executes `JRST 100(3)` with
AC3=`765432,,000005`; the required target is `000105`, proving only the right
half participates. A fetch-only backing object proves the step performs only
the instruction fetch. All nonzero JRST AC functions and indirect addressing
remain outside the bounded CPU.

The admitted path now executes through the two halfword instructions at
`040034`/`040035`; the next untouched instruction is
`040036 251600,,000007` (`BLT 14,7`).

## Indexed I/O boundary

The word at `040006` is:

```text
701215,,000000
CONO PAG,0(15)
```

For the bounded section-zero/direct form, the 18-bit effective condition is
`Y + RH(AC[X])` modulo `2**18`. The early real path has AC15 octal equal to
zero, so E=0. Later MTBOOT sets AC15 to `000000,,000047` and executes the same
indexed instruction again; E is then `000047`, which loads PAG EBR=`047000`
and invalidates translation state while leaving paging disabled. A following
`DATAO PAG,1` reads the live AC1 word through `KL10AddressSpace` and loads
UBR=`047000`.

The PAG object exposes EBR/UBR, pager-mode bits and a translation-invalidation
generation but still does not implement page walking. Controls that actually
enable address translation, or DATAO context/previous-section controls not yet
modeled, reject explicitly rather than being ignored.

## MOVSI boundary

The real word at `040007` is:

```text
205740,,254016   MOVSI 17,254016
```

For the admitted direct form, MOVSI loads the 18-bit E value into the left
half of the selected accumulator and clears the right half. It performs no
operand memory read. A synthetic guard starts AC17 at `777777777777` and
executes `MOVSI 17,123456`; the required result is `123456000000`. The
string radix helper independently pins the instruction word as
`205740123456` octal = `42F80A72E` hex, correcting another proposed
hand-written hex fixture.

The real seventh step leaves AC17=`254016,,000000` and PC=`040010`.  Version
0.12 then executes the direct `JSP 16,17`.  The bounded CPU's processor flag
word is explicitly zero and none of the previously admitted instructions
change it, so JSP saves:

```text
AC16 = 000000,,040011
PC   = 000017
```

Address `000017` is the accumulator window. The instruction fetched from AC17 is:

```text
254016,,000000   JRST 0(16)
```

Version 0.14 executes that plain indexed JRST back to `040011`; v0.15 executes
`SUBI 16,11`; v0.16 executes the indexed Boolean-family `AND 0,124(16)`; v0.18
adds the MOVE family; v0.19 executes the following shift, logical-test,
PAG/APR, SKIP, CONSO and branch sequence; v0.20 executes `HRRI`/`HRLI` to
construct AC14=`047000,,000001`; v0.21 executes `BLT 14,7` as seven live
address-space cycles; v0.22 adds `EXCH`; and v0.23 closes the preserved-tape
handoff through `MOVEM`, `AOS`, and `SOJG`.  The resulting AC-resident loop runs
with AC11/AC12 as live addresses and AC13 as its `036000`-octal count.  A
complete debug replay reaches the loop exit at step 92192 and transfers through
AC7 to `771044`; the tape-derived post-loop acceptance then proves the real
`AOBJN` loop at `771077`.  No later unsupported-opcode boundary is claimed by
v0.23. Nonzero JSP flag-state semantics, indirect/indexed JSP, non-plain JRST
functions, actual paged address translation, indirect I/O, BLKI/BLKO channel
semantics, and real PI/DTE/front-end behavior remain outside the bounded CPU.

## Acceptance

Run from `tests/`:

```sh
rexx test_octal_bits.rex
rexx test_lroct.rex
rexx test_lroct_orderable.rex
rexx test_lroct_randomized.rex
rexx test_simh_framing.rex
rexx test_cpu_tdz.rex
rexx test_cpu_skipa.rex
rexx test_cpu_apr_reset.rex
rexx test_cpu_pag_coni.rex
rexx test_cpu_pag_cono_indexed.rex
rexx test_cpu_andi.rex
rexx test_cpu_movsi.rex
rexx test_cpu_move_family.rex
rexx test_cpu_halfword_family.rex
rexx test_cpu_exch.rex
rexx test_cpu_blt.rex
rexx test_cpu_aobj.rex
rexx test_cpu_aos_family.rex
rexx test_cpu_soj_family.rex
rexx test_cpu_shift_family.rex
rexx test_cpu_skip_family.rex
rexx test_cpu_pag_datao.rex
rexx test_cpu_io_boundary.rex
rexx test_io_bus_routing.rex
rexx test_cpu_jsp_ac_fetch.rex
rexx test_cpu_add_sub_family.rex
rexx test_cpu_boolean_family.rex
rexx test_cpu_test_family.rex
```

Live state walk:

```sh
rexx ../tools/MTBootThirtyThreeSteps.rex /path/to/bb-h137f-bm.tap
rexx ../tools/MTBootStateWalk.rex /path/to/bb-h137f-bm.tap 38
rexx ../tools/MTBootPostLoopAOBJ.rex /path/to/bb-h137f-bm.tap 28
```

Tape-dependent tests:

```sh
rexx test_kl10_ipl.rex /path/to/bb-h137f-bm.tap
rexx test_raw_tape_loader.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_one_step.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_two_steps.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_three_steps.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_four_steps.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_five_steps.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_six_steps.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_seven_steps.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_eight_steps.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_nine_steps.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_ten_steps.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_eleven_steps.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_fourteen_steps.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_twentyfour_steps.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_twentysix_steps.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_thirtythree_steps.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_thirtyeight_steps.rex /path/to/bb-h137f-bm.tap
rexx test_mtboot_postloop_aobj.rex /path/to/bb-h137f-bm.tap
```

## External historical fixture

The tape is not redistributed:

```text
bb-h137f-bm.tap
bytes:   22588724
SHA-256: 7248864ad885ee89f4c3e93b0dfa266bfa5e79c136f3cace300480df179780f7
```


## Component test runner

The package now follows the same top-level convention as the other ooRexx
components:

```text
./run_tests.sh
./run_tests.sh core
./run_tests.sh tape
./run_tests.sh states
./run_tests.sh integrations
```

`all` is the default. The self-contained core suite always runs. Historical
media/checkpoint and companion-component tests are enabled by environment
variables rather than embedding large archaeology fixtures in the component:

```text
KL10_TAPE
KL10_PROMPT_STATE
KL10_AFTER_ENTER_STATE
KL10_PRE_MAP_STATE
KL10_PRE_PAGING_STATE
KL10_PRE_DTE_STATE
KL10_NO_READY_STATE
KL10_FIRST_READ_STATE
KL10_PROBE_762000_STATE
QUEUE_FABRIC_ROOT
TERMINAL_MACHINE_ROOT
```

Missing external fixtures are reported as `SKIP`. Test or compile failures
return non-zero. A plain no-fixture `./run_tests.sh` currently reports:

```text
KL10 TEST SUMMARY: PASS=49 SKIP=16 MODE=all
```



## v0.31-dev4: second physical tape record and RH20 scatter/gather

The real MTBOOT `/L` path now reaches a second TU45 READ FORWARD. The preserved
BB-H137F-BM reel advances:

```text
position 2568 -> 5136
record   DATA, 2560 bytes, 512 x 36-bit words
word 0   064250,,347640
```

The second record is not transferred by one CCW. MTBOOT installs:

```text
762000  400400,,000000   FWD DATA XFER       WC=020  ADR=000000
762001  617400,,000020   FWD DATA XFER,LAST  WC=760  ADR=000020
```

so the RH20 must scatter one 512-word tape record into two physical ranges:

```text
record words   0..15   -> physical 000000..000017
record words  16..511  -> physical 000020..000777
```

`executeReadChannel()` now walks a bounded consecutive CCW list until LAST,
carries the tape-record index across segments, refuses zero-length/unsupported/
overflow/premature-LAST command lists, writes logout state after the final CCW,
clears PCR FULL and asserts CMD DONE. DMA remains explicitly physical; the
first sixteen words therefore do not alias the CPU AC window.

The authentic second-read checkpoint is:

```text
PC      774445
ICOUNT  852340
TU45    5136
```

`test_rh20_multiccw_read.rex` proves the channel semantic directly against the
real reel. `test_second_read_real_state.rex` proves that MTBOOT itself reached
the same result.

## v0.31-dev4 phase-one region-cycle accelerator

A complete phase-one MTBOOT low-memory region cycle has been frozen and compared
against ordinary execution. From PC `774673` to the next `774673`, its only
persistent architectural delta is:

```text
ICOUNT             +2542
AC1                +001000
AC2                +001000
AC13               +001000
PAG tlbFlushCount  +62
physical 772272    new inclusive region end
next 512 words     cleared
```

The accelerator is pinned to the exact phase-one stack context, fingerprints
the relevant MTBOOT code, requires identity translation of the target range,
and refuses the configured-range boundary. Its full frozen-state oracle,
including canonical memory digest and mounted tape state, passes.

This changes host work only. One 500-work-unit run represented 539,084
historical KL10 instructions before MTBOOT entered its next genuine phase.


### Continued reel stream

After the special second-record scatter, MTBOOT rewrites the channel list to a
single full-page LAST CCW. The third authentic read is:

```text
TU45        5136 -> 7704
PC          774445
ICOUNT      853475
CCW         620000,,001000
transfer    512 words -> physical 001000..001777
word 0      000001,,056174
word 511    000001,,521615
```

The fourth read uses the same form at physical `002000..002777`. Subsequent
bounded continuous execution has consumed 21 complete records from tape file 0
without requiring another RH20 semantic, reaching:

```text
TU45 position  53928
PC             774551
ICOUNT         874780
```

`tools/KL10RunContinuous.rex` is provided for this mode. It does not stop on
media motion; it still stops on an architectural refusal or work-unit limit and
always freezes the resulting complete machine state.

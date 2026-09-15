# Journal-pointed live archaeology

This emulator deliberately combines two capabilities that are unusually useful
for historical-machine reconstruction:

1. journal-pointed architectural state that can rewind the live machine to an
   exact pre-instruction point; and
2. object-scope ooRexx method insertion/replacement on the instruction
   executor.

They are complementary.  Neither replaces durable freeze files.

## Why the combination matters

An unsupported instruction is detected before architectural state is changed.
That gives a clean historical boundary.  A journal point can be taken at that
boundary, an `OPxx` implementation can be installed on the *existing executor
object*, and the machine can be rewound to the same CPU/storage/channel/clock
state before retrying the same instruction.

The installed method is deliberately outside the journalled machine state.  A
rewind therefore removes speculative architectural effects while leaving the
new executable method available.  Re-installing the same object method name
replaces the previous trial in place, allowing trial A -> rewind -> trial B ->
rewind without rebuilding the package or restarting the emulator.

This changes the archaeology loop from:

    observe -> edit source -> rebuild/restart -> replay IPL -> hope state matches

to:

    observe -> checkpoint -> insert/replace method -> rewind -> exact retry

Only a method that makes the guest progress plausibly from the exact historical
state is promoted to permanent source.

## Advantages already demonstrated

- **Exact-state A/B testing.**  Different candidate semantics can be tried
  against the same PSW, registers, storage and device position instead of
  against a merely similar reboot.
- **Atomic failure boundary.**  Unsupported instruction preflight leaves IA,
  instruction count and architectural state unchanged, making the retry point
  trustworthy.
- **Patch survives rewind; machine effects do not.**  This is the key property
  proven by `test_executor_live_method_replacement.rex` and the journal live
  patch regressions.
- **In-place replacement.**  Calling `installLiveMethod()` again for the same
  `OPxx` name replaces the object-scope trial, so alternative semantics can be
  compared without contaminating dispatch tables or permanent source.
- **Promotion after guest proof.**  The permanent implementation can be kept
  small and evidence-led because the guest has already exercised the candidate
  at the real frontier.
- **Shorter archaeology loops.**  Expensive IPL and loader paths need not be
  replayed for every candidate once a suitable journal point is available.
- **Fork/diff potential.**  Journal-pointed state naturally supports comparing
  consequences of alternative live methods from a common parent state.
- **Better diagnostic retention.**  A disappearing diagnostic is not accepted
  as success; the before/after state and subsequent guest progress can be
  compared directly.

## Boundary with freeze files

Freeze files remain the durable, externally verifiable whole-machine evidence
and replay format.  Journal points are live history for rewind/fork/diff/retry.
A journal may use a freeze checkpoint as a base, but journal history is not
serialized into or substituted for the freeze format.

This separation is important: live archaeology can be aggressive and cheap
while durable evidence remains stable and independently verifiable.

## Current limitations

The current channel journal adapter intentionally fails closed when asked to
reconstruct pending I/O interruption state for which no reconstruction codec is
implemented.  Live archaeology must therefore choose checkpoints that are
within the supported journal state envelope, or use durable freeze/replay and
guest evidence instead of inventing missing device state.

## AF / Monitor Call worked example

The safety6 -> safety7 Monitor Call boundary demonstrates the separation of
lifetimes directly.  Real MVT exposed `AF030FFF` at IA `016606`, instruction
count `511776`.  Before permanent AF support existed, the executor returned
`UNSUPPORTED` without advancing IA or instruction count.

A live `OPAF` candidate was then inserted while an instruction journal point
was active.  The experiment deliberately changed CR8, a GPR and RAM after the
checkpoint and then aborted the instruction.  The journal restored those
architectural changes, while the object-scope `OPAF` method remained attached
to the executor.  The same historical MC invocation could therefore be retried
with new semantics but old machine state.

The first candidate implemented only the already-proven reset-zero CR8 case.
It was subsequently replaced *under the same `OPAF` name* with a second
candidate that decoded the monitor class and selected the corresponding CR8
mask bit.  Another rewind restored the invocation state, and the replacement
method—not the original—ran on retry.  Enabling the class-3 mask deliberately
failed closed because the monitor-event interruption path has not yet been
qualified.

That experiment highlights several practical advantages:

- uncertainty in instruction semantics does not require losing a valuable live
  guest state;
- speculative machine changes and speculative executable code can be given
  independent lifetimes;
- a hypothesis can be refined by replacement rather than by accumulating
  patches or dispatch special cases;
- the exact same invocation can be used to distinguish two close semantic
  hypotheses;
- the successful hypothesis can be promoted to permanent source only after the
  live trial has established the narrow behaviour the guest actually needs;
- unproven branches can remain fail-closed instead of being invented merely to
  make the guest continue.

This is particularly valuable on this project because reaching a frontier can
require hundreds of thousands of interpreted guest instructions.  Preserving
and revisiting the frontier is therefore much more informative—and much less
expensive—than repeatedly treating IPL as the unit of experimentation.

## BAL alias worked example: rewind the cause, not the symptom

The safety7 -> safety8 frontier initially appeared to be an unsupported primary
opcode `B0` at IA `018A72`.  External architecture evidence showed that `B0`
is in fact undefined on System/370, so manufacturing an `OPB0` implementation
would have hidden rather than repaired the machine defect.

A short backwards trace identified the immediately preceding control transfer:
`45A0A0EA` at IA `018984`, BAL R10 with R10 also used as B2.  The pre-instruction
R10 value was `00018980`, so the RX effective address is `018A6A`.  The old
executor instead wrote the BAL link `B0018988` to R10 and *then* formed the RX
address, causing it to branch eight bytes too far to `018A72` and fetch the
undefined `B0` from what was never the intended instruction boundary.

This made a particularly strong live-archaeology experiment:

1. execute the old BAL under an instruction journal point and reproduce
   `018A72`;
2. abort the instruction and recover IA `018984`, the old R10 and the original
   instruction count;
3. insert a corrected object-scope `OP45` that forms EA before writing R1;
4. deliberately dirty a GPR and RAM, abort again, and observe that the machine
   state rewinds while the inserted method survives;
5. retry the *same* BAL and land at `018A6A` with link `B0018988`;
6. continue the real guest from that state and require plausible forward
   progress rather than merely the disappearance of `B0`.

Real MVT then executed another 87 instructions before exposing a new boundary
at IA `014FCA`, opcode `13`.  The lesson is important: a frontier can be a
*symptom* of an earlier sequencing defect.  Journal rewind plus live method
insertion lets the investigation move one instruction backwards without
losing the expensive historical state, while method replacement makes it
possible to compare alternative causal repairs on the same state if needed.

## Durable freeze coverage versus live journal coverage

The separation between freeze files and journals is architectural, not merely
terminological.  The current `IBM4361State` v2 durable codec intentionally
fails closed for attached device classes without an explicit freeze codec.  In
particular, the present durable codec does not yet serialize a real-MVT machine
with the 3330 CCKD device and 3215 console attached.  Therefore the BAL
archaeology point cannot honestly be advertised as a durable whole-machine
freeze today.

The live journal can still be used at supported points because it journals the
running objects in-process.  Evidence logs, exact media identity and focused
microstates remain useful, but they are not substitutes for a future durable
3330/3215 freeze codec.  Extending the freeze format to those device classes is
therefore a useful independent follow-up; it must not be achieved by leaking
journal internals into the freeze representation.

## LCR worked example: prove the narrow path, fail closed on the unproven one

The safety8 -> safety9 LCR boundary at IA `014FCA` illustrates another useful
property of live instruction replacement: a candidate does not need to pretend
to solve every architectural branch before it can be tested against the real
guest.

The actual MVT invocation contained R7=`FFFFFFF4` (-12), CC1 and program mask
zero.  A live `OP13` was inserted after the unsupported attempt, the journal
rewound the machine to the exact invocation, and the method remained installed.
Retry produced R7=`0000000C`, CC2 and allowed 27 more guest instructions before
the next unsupported boundary.

The awkward X'80000000' complement case was covered separately.  With overflow
mask off, the live/permanent implementation leaves X'80000000' and sets CC3.
With fixed-point-overflow masking enabled, the emulator currently fails closed
because its exact program-interruption sequence has not yet been qualified.
That is intentional: live insertion lets us promote the path the guest has
proved without inventing an unrelated interruption mechanism merely to make a
test return `OK`.

This makes the experimental layer useful for both acceleration and restraint:
it is cheap to try more code, but also cheap to keep uncertain code out of the
permanent machine.

## NR worked example: journal the machine, not the hypothesis

At the safety9 -> safety10 NR frontier, the live experiment deliberately dirtied
a GPR and RAM after installing OP14, then aborted the instruction.  The journal
restored those architectural changes and the exact NR invocation, while the
object-scope OP14 remained installed.  The same guest state could therefore be
retried immediately and then run forward to the next boundary.  This is the
intended asymmetry: speculative machine consequences are cheap to discard;
speculative executable hypotheses are cheap to retain, replace, compare, or
remove independently.

## AL worked example: withdraw the candidate and expose permanent code

Safety10 -> safety11 extends the experimental lifecycle beyond insertion and
replacement.  At the real MVT AL frontier (`5E60C888` at IA `0154D0`), sealed
safety10 first returned `UNSUPPORTED` atomically.  A live `OP5E` was installed;
a GPR and RAM were deliberately dirtied; journal abort restored the machine but
left the candidate attached.  Exact retry produced R6=`C0016A60`, CC1 and
advanced to `0154D4`, after which MVT ran another 296 instructions to X'56'.

The executor now also exposes `removeLiveMethod()`.  Removal has the same
intentional lifetime as insertion/replacement: it is executable-hypothesis
state, not journalled machine state.  A journal abort therefore does not
resurrect a removed object method.

This enables a direct promotion bridge.  The recorded AL microstate is executed
once through the successful live candidate, rewound, the object override is
removed, and the same microstate is executed again through permanent class
`OP5E`.  The test requires identical destination register, condition code, next
instruction address and storage operand.  Promotion can therefore be checked
without making a second full IPL the unit of comparison.

The practical model is now:

    machine history: checkpoint -> speculate -> rewind
    code hypothesis: insert -> replace -> remove
    durable evidence: freeze / media identity / evidence log

Those three histories are related, but deliberately not collapsed into one
serialization or lifecycle.

## O worked example: promotion bridge reused at a later frontier

Safety11 -> safety12 demonstrates that the removal-based promotion bridge is not
AL-specific.  At IA `0146FC`, sealed safety11 exposed `561C0004` as unsupported.
The live OP56 candidate ORed R1=`00035EC8` with the fullword `FC000000` at EA
`035EDC`, producing `FC035EC8` and CC1 while leaving storage unchanged.  The
journal restored deliberate GPR/RAM dirt but retained the live method; MVT then
advanced 803 instructions to the next unsupported boundary.

The exact recorded microstate is also used for candidate->permanent equivalence:
run the live method, rewind, remove the object override, and run permanent OP56.
This repeated use confirms that method removal is a general promotion mechanism,
not a one-off AL test convenience.

## NC worked example: overlap semantics and a non-opcode frontier

Safety12 -> safety13 shows two further advantages of the live-archaeology model.
At IA `00660C` MVT executes a four-byte self-NC (`D403A0A0A0A0`) against
`00B0A0`.  The live candidate is deliberately byte-sequential, so destructive
overlap is a property of the implementation rather than an accident hidden by
whole-string snapshots.  Focused tests distinguish those two behaviours and
also cross the 24-bit `FFFFFF -> 000000` wrap boundary.

The real guest retry leaves its four zero bytes unchanged, changes CC1 to CC0,
and then advances another 227 successful instructions.  The following frontier
is opcode X'00' at IA zero.  That is not treated as another instruction to
invent: the experimental loop has exposed a different class of question,
namely program-interruption/control-flow archaeology.  Live methods therefore
help not only to add missing semantics cheaply, but also to avoid adding code
when the evidence says the problem belongs to another architectural mechanism.

Candidate->permanent promotion again uses method removal: execute the live
candidate, rewind the exact microstate, remove the object override, and dispatch
through permanent OPD4.  Machine history and code-hypothesis history remain
independently reversible.

## Safety14: late handoff into journalable state

Safety14 adds a useful pattern for expensive historical trajectories.  The already-known MVT lead-in runs on ordinary sparse RAM.  At the exact operation-exception frontier the explicit architectural component states are copied, in-process, into an equivalent machine backed by `IBM370JournaledStorage`.  The clone is verified before experimentation.  Only then is the checkpoint opened and the live program-interruption hypothesis installed.

This preserves the separation of concerns: the journal is not required to record every instruction merely because a later instruction may need archaeology.  A journal-capable element can become the execution substrate at the point where reversibility is valuable, while freeze remains the durable whole-machine evidence format.  The method hypothesis still has an independent lifetime: it survives machine rewind, can be replaced, and can be removed to expose the permanent class method at the exact same microstate.

## Safety15: object identity in test/probe helpers

Safety15 exposed a small but important ooRexx rule while building the ALR
regression. A helper procedure that accepts an emulator machine or component
must bind it with `use arg`, not `parse arg`. `use arg` preserves the object
reference. `parse arg` applies parsing/string semantics and can therefore turn
what was intended to be an object-bearing helper path into a string path.

This matters to live archaeology because the value of the method-insertion
model depends on exercising the same live objects that own CPU, storage,
journal and executor state. Test helpers now follow the rule:

    object arguments: use arg
    scalar/text parsing: parse arg

The ALR frontier then repeats the promotion pattern at larger forward distance.
At IA `01A482`, ALR R10,R11 is first unsupported on sealed safety14. After
exact state handoff to journal RAM, the object-scope candidate is installed,
machine dirt is rewound while code survives, and retry produces R10
`60000002`, CC1. The guest runs another 7,844 successful instructions. The
same recorded microstate is then used for candidate -> rewind -> remove live
method -> permanent OP1E equivalence.

## Safety16: architecture classification can be live-replaced too

Safety16 extends the same reversible-code idea beyond OPxx methods.  At the
real X'FF' boundary, the machine first remains atomic because the permanent
classifier does not yet identify FF as an architectural exception.  A live
object-scope replacement of `architecturalOperationException()` then survives
journal rewind while CPU/RAM dirt is discarded.  Retrying the same machine
state delivers the program interruption without creating a fake OPFF method.
After proof, removal of the live classifier exposes the promoted permanent
allow-list at the identical microstate.  This demonstrates that live
archaeology applies to semantic dispatch/classification seams as well as
instruction bodies.

## Safety17: architecture-version-specific classification

Primary X'C4' illustrates why a live classifier must include the target
architecture in its reasoning.  Later IBM architectures reuse parts of the C4
space, but the current guest is System/370.  Safety17 therefore trials and
promotes C4 only after System/370-specific evidence plus exact MVT forward
progress.  The positive allow-list remains deliberately narrower than a generic
"unknown means operation exception" rule, preserving unsupported emulator gaps
as clean archaeology boundaries.

## Safety19: architectural validity before implementation coverage

An assigned instruction can program-check before its normal semantics are
reached.  At the MVT X'5D' frontier, `D` names odd R1=B; System/370 requires an
even register pair and raises specification exception before divisor fetch.
Safety19 therefore does not invent OP5D merely to pass the diagnostic.  A live
specification classifier/delivery method is inserted, the exact state is
rewound/retried, then promoted as a preflight that runs before implementation
coverage.  A dummy OP5D regression proves that future instruction implementation
cannot bypass the already-proved architectural validity check.

## Safety24: exceptions raised by an EX transient target

Safety24 extends the same-state method-lifetime technique from missing opcodes
to a subtler sequencing defect.  The visible boundary was already-implemented
EX (`44 @ 0004B6`), whose transient target was an invalid-register STE.  The
pre-Safety24 step method stopped atomically as `UNSUPPORTED_EX_TARGET`.

With an instruction journal point active, the executor's `step` method was
replaced at object scope with a candidate that asks architectural validity of
the EX target before ordinary coverage.  Deliberate GPR/RAM mutations were
then rewound while the replacement method survived.  Retrying the *same EX*
produced old PSW `00040006800004BA` and loaded program-new PSW
`00040000000002CA`.  The candidate was later removed and permanent source was
proved equivalent from the identical state.

This is another reason executable hypotheses must have a lifetime independent
of machine history: the experimental unit was not an opcode method at all but
the executor sequencing method that decides whether a transient EX target is a
coverage gap or an architectural interruption.

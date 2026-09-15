# Live journal integration — separate from freeze files

`IBM4361Journal.cls` is an optional in-process execution-history adapter for the
IBM 4361 emulator.  It uses the external `JournalPointedState.cls` component.

It is **not** a new freeze format and does not change `IBM4361State.cls`.

## Two different facilities

### Durable IBM freeze

`IBM4361State` remains the architectural/export boundary:

- whole-machine state;
- explicit/versioned records;
- SHA-512 sealed;
- save/load into a fresh process/machine;
- external media identity is part of the durable contract;
- suitable for evidence, reproducible archaeology and long-lived checkpoints.

### Journal-pointed live history

`IBM4361JournalSession` is for a running testbed:

- cheap pointer checkpoints;
- reversible event/instruction history;
- retained failed futures and branch/retry;
- live method insertion followed by rewind;
- watcher/progress integration through `StateOfNationController`;
- no claim of process durability.

A caller may restore any retained journal point and *then* take an ordinary
`IBM4361State` freeze.  The journal itself is not serialized into that freeze.

## RAM delta model

`IBM370JournaledStorage` subclasses `IBM370Storage` and records only changes made
inside an active journal event.  Bulk stores are retained as one old/new range
delta, so a 256-byte MVC or channel transfer is not expanded into 256 state
snapshots.  Storage-key changes use their own compact deltas.

Journal moves replay those deltas forward/backward against the live sparse RAM.
The old branch remains retained when execution forks after a rewind.

## Instruction transaction

Typical use:

```rexx
ram=.IBM370JournaledStorage~new(16*1024*1024,2048,"MVT-RAM")
m=.IBM4361Machine~new(16*1024*1024,ram)
session=.IBM4361JournalSession~new(m,frontEnd)

cp=session~beginInstruction(context)
/* execute exactly one guest instruction/event */
session~commitInstruction(context)
```

If execution faults after speculative writes:

```rexx
result=session~recoverInstruction( -
    "MISSING_INSTRUCTION", executor, "OPD5", context)
```

The live recovery coordinator installs the new object-scope method, then the
State-of-the-Nation controller restores the pre-instruction journal pointers.
Machine state goes backward; code deliberately remains patched.

## Mutation ownership

Once a journal session is attached, execution mutations intended to be
rewindable must occur inside its event boundaries.  Pointer-only checkpoints do
not discover arbitrary out-of-band mutations after the fact.

## Current recovery-tree limitation

This recovery2 base still has the older channel subsystem codec, which refuses
pending interrupt reconstruction.  The journal channel adapter therefore fails
closed if `pendingInterruptCount` is non-zero.  When the later v7 channel state
is recovered, its pending-interrupt state must become a journal participant too;
it must not be guessed or silently dropped.

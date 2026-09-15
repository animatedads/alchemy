# Source provenance

This cut was created against the user-supplied ooRexx/API roll-up on 2026-08-24 and validated with ooRexx 5.3.0 r13196.

## Shared house components — referenced, not carried

Required at validation/runtime by `REXX_PATH`:

- Alchemy Objects v0.8 (`AlchemyObject.cls` and its package-owned dependencies)
- ooRexx Crypto v0.1 (`crypto.cls`)
- msqlshim v0.21a manual hotfix (`MySQLDeflate.cls`; internal directory label may still read v0.22)
- ooRexx Journal Pointed State v0.1 (`JournalPointedState.cls`) for the optional live journal adapter

The IBM component ZIP contains no shared library copies. Journal Pointed State is a live in-process dependency only; it is not part of the IBM durable freeze-file format.

## Architectural/reference sources

- IBM System/370 Principles of Operation, including the IPL implied CCW and command-chaining sequence.
- Hercules Emulator V3.12 User Reference Guide.
- SDL Hercules Hyperion `esa390.h` and related source as an independent implementation oracle.
- CBT Tape OS/360 page describing the February 2003 Rick Fochtman and Jay Maynard MVT distributions.

No Hercules implementation code is copied into the IBM machine implementation. No OS/360/MVT media is embedded in this package.

## Safety11 continuation

Safety11 is derived from the sealed safety10 handover archive.  Permanent source
changes are limited to System/370 AL (`X'5E'`) and the generic object-scope
`removeLiveMethod()` executor seam.  The AL semantics were first proved as a
live method against the exact real-MVT frontier using the sealed safety10 class
path and the supplied `MVTRES.350` image.  Permanent promotion is additionally
qualified by a same-microstate live-candidate -> remove-override -> permanent
class-method equivalence test.

External architectural oracle: Hercules System/370 `add_logical` implementation
and opcode table, used only as independent semantic evidence; no Hercules code
is vendored into this package.

## Safety12 continuation

Safety12 is derived from sealed safety11.  The only permanent instruction
promotion is System/370 X'56' O / Or.  Live semantics were proved first against
the exact real-MVT frontier using the sealed safety11 class path and supplied
MVTRES.350.  Permanent promotion is additionally checked by same-microstate
candidate->remove->permanent equivalence.  Hercules general-instruction source
was used only as an independent semantic oracle; no Hercules code is vendored.

## Safety13 continuation

Safety13 is derived from sealed safety12.  The only permanent instruction
promotion is System/370 X'D4' NC / And Character.  The exact real-MVT path was
proved first as an object-scope live method against the sealed safety12 class
path.  Permanent promotion is independently checked by same-microstate
candidate->remove->permanent equivalence.  The implementation preserves
left-to-right destructive overlap and 24-bit address wrap.  No OP00 is added;
address-zero execution is reserved for program-interruption/control-flow
archaeology.

## Safety18 continuation

Safety18 is derived from sealed safety17. The only permanent semantic promotion
is System/370 primary X'62' into the narrow architectural operation-exception
positive allow-list. The exact real-MVT state was first retried under an
object-scope live classifier with journal rewind; no synthetic OP62 instruction
exists. The supplied `oorexxapis(20260901-105327).zip` was inspected for current
integration context and contains Maths v0.5 / Foreign Runtime v0.22.5, but
Safety18 does not add either as a runtime dependency. They remain prospective
independent precision/proof providers for later hexadecimal-floating-point work.

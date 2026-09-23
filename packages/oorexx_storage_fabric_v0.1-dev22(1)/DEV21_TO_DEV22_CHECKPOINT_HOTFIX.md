# Storage Fabric dev21 -> dev22 checkpoint canonical-integer hotfix

A live dev20 backup checkpoint exposed this trailer:

    ... 20260921T13:30:43.663021    2.18468359E+9

The final field is the STORAGE-XFER-CKPT-1 Adler-32 checksum.  It is durable
integrity evidence, not display text.  Scientific notation there proves that
the checkpoint codec inherited Rexx numeric rendering from a low-precision
context.

Dev22 makes checkpoint integer text canonical and caller-independent:

- sequence: decimal digits only;
- total bytes: decimal digits only;
- bytes transferred: decimal digits only;
- chunk bytes: decimal digits only;
- Adler-32 checksum: decimal digits only.

No exponent notation, signs, whitespace or leading zeroes are accepted.
Legacy/scientific numeric checkpoint fields fail closed and the transfer starts
from trusted byte zero (or reconciles an already-committed final object through
normal destination verification).

The arithmetic precision repair from dev21 remains in force.  This change adds
a separate persistence-format invariant: high NUMERIC DIGITS is not a substitute
for canonical durable serialization.

Production gate on ooRexx 5.3.0 r13196:

    /usr/local/bin/rexx tests/test_large_file_precision.rex

Expected:

    PASS large-file exact byte precision and tail read

The test now also verifies that the checkpoint checksum contains no exponent and
that a synthetic `2.18468359E+9` checksum trailer is rejected.

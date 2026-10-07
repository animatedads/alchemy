# RecordSet v0.1-dev2 validation

Executed locally against the supplied toolchain sources.

- strict host C90 compile of the MVS semantic backend + fake driver: PASS, zero warnings
- MVS resource/metadata/record contract test: PASS
- portable RecordSet regression test: PASS
- `RecordSetNativeMvs.c` through cc370 `-S`: PASS
- generated S/370 assembler size: 64561 bytes

The fake driver proves the backend/driver contract only. It is not represented as
native MVS I/O. The outstanding native implementation is the QSAM/DCB driver
behind `RecordSetMvsDriver.h`.

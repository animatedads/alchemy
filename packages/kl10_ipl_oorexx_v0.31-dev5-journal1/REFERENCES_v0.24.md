# References for v0.24

- DEC PDP-10 / DECSYSTEM-20 Processor Reference Manual (1982), instruction and memory-management definitions: https://www.bitsavers.org/pdf/dec/pdp10/1982_ProcRefMan.pdf
- DEC KL10 / extended-addressing PXCT discussion, including Previous Context Section/User/AC Block and PXCT AC-field semantics: https://bitsavers.org/pdf/dec/pdp10/KC10_Jupiter/ExtendedAddressing_Jul83.pdf
- SIMH PDP-10 pager implementation, used as a cross-check for KL/KS TOPS-20 page-table sequencing and AC-block/UBR state: https://src.rivoreo.one/emulators/simh/%2B/1c4a1ed87141e5586d590bb28832b9081e477bb5/PDP10/pdp10_pag.c
- PDP-10 opcode table, cross-checking `120` as DMOVE and `256` as XCT: https://pdp10.nocrew.org/docs/opcodes.html

The preserved tape fixture used for executable acceptance is external to this package:

- `bb-h137f-bm.tap`
- size: 22,588,724 bytes
- SHA-256: `7248864ad885ee89f4c3e93b0dfa266bfa5e79c136f3cace300480df179780f7`

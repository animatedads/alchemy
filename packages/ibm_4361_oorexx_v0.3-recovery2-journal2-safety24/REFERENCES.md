# References used for v0.2 boundary

- IBM System/370 Principles of Operation, GA22-7000 family: Initial Program Loading and channel-program architecture.
- IBM System/370 Operator's Reference material for CCW/CSW field layouts and flag meanings.
- Hercules Emulator V3.12 User Reference Guide (HEUR031200-00), used to contrast operational suspend/save facilities with this project's architectural checkpoint contract.
- SDL Hercules Hyperion source, especially `esa390.h`, as an independent implementation/source oracle for prefixed storage and named architectural state.
- CBT Tape OS/360 download page for provenance of Rick Fochtman's OS/360 material and Jay Maynard's OS/360 MVT turnkey distribution.

No Hercules implementation code or historical IBM/CBT guest media is copied into this component. References are used as architectural/configuration evidence and test oracles.

## IBM System/370 Reference Summary

- GX20-1850-5, Sixth Edition, July 1984.
- For Safety22 X'02': CODE TABLES, printed page 14, physical PDF page 20 (1-based), where hex 02 has no instruction assignment and hex 06 is BCTR.
- For Safety23 navigation: Floating-Point Instructions (Cont'd), printed page 5, physical PDF page 11 (1-based), lists STE as opcode X'70' RX.

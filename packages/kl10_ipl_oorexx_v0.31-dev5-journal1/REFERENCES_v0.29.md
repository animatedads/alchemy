# References v0.29

Byte pointers:
- DECsystem-10 / DECSYSTEM-20 architecture documentation for local byte pointer
  format P,S,00,I,X,Y and ILDB/IDPB/DPB semantics.
- v0.29 validates these semantics against the real MTBOOT post-ENTER state:
  IDPB increments before deposit; DPB does not increment; I/X/Y participate in
  ordinary section-zero effective-address calculation.

RH20:
- DIGITAL RH20 Massbus Controller hardware documentation. RH20 select codes are
  540, 544, 550, 554, 560, 564, 570, and 574 (octal).
- CONO RH20 bit 25 / right-half 002000 is CLR MBC.
- CONO RH20 bit 27 / right-half 000400 is MASSBUS ENA.
- OpenSIMH PDP-10/KL10 sources and device configuration material were used as
  implementation cross-checks; v0.29 does not infer a ready tape unit from
  controller presence.

Current KL10_STATE/1 schema SHA-256:
`1d270bf80502a1d8ffe40e350ef4455ffcd68d3f9243b0cee53f30d9bb3ea9a9`.

Previous DTE-only schema SHA-256 retained for exact migration:
`dd12699496f2a068969f504c24cbce720bfcfee52d4e45a18eac88e84434e222`.

Preserved tape SHA-256:
`7248864ad885ee89f4c3e93b0dfa266bfa5e79c136f3cace300480df179780f7`.

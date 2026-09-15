# References v0.27

Hardware and pager semantics:
- DIGITAL, *KL10-Based DECsystem-10/DECSYSTEM-20 Technical Manual*, Appendix A.7
  "The MAP Instruction", EK-OKL10-TM-002. Bitsavers:
  https://www.bitsavers.org/pdf/dec/pdp10/KL10/EK-OKL10-TM_KL10_TechRef_Aug84.pdf
- The MAP table defines AC bit 02 as a true mapping indication; bits 03/04/06/07/08
  report modified/writable/public/cacheable/keep state; bits 14-35 contain the
  physical address.

Front-end reference implementation:
- Richard Cornwell, SIMH KL10 front-end:
  https://github.com/simh/simh/blob/8a4b3752bb99c2b3fd800dec57b0c8eb37158d27/PDP10/kl10_fe.c
- Relevant definitions include DTE device 0200 and secondary locations:
  DTFLG=0444, DTF11=0450, DTCMD=0451, DTCHR=0454, DTMTD=0455, DTMTI=0456.
- `dte_second()` services MONO/MONON and acknowledges commands by clearing DTCMD
  and setting DTFLG. `dtei_svc()` places monitor input into DTF11 and sets DTMTI
  only when the monitor-input flag is clear.
- Reset leaves DTE_SEC as internal state; guest CONI masks to the low 18 bits.

The preserved tape identity remains SHA-256
`7248864ad885ee89f4c3e93b0dfa266bfa5e79c136f3cace300480df179780f7`.

Current KL10_STATE/1 schema SHA-256:
`dd12699496f2a068969f504c24cbce720bfcfee52d4e45a18eac88e84434e222`.

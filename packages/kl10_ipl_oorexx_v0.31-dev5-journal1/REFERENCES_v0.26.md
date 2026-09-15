# References v0.26

v0.26 introduces no new KL10 hardware semantics. It hardens execution-state
provenance, reconstruction, and observation around the architectural semantics
already referenced through `REFERENCES_v0.24.md`.

The state schema canonical declaration is:

`KL10_STATE/1|CPU:pc,flags,halted,mode,icount|AC:8x16|BUS:code,name,schema|APR:resetCount,resetDone,aprIrq,irqEnable,irqFlags|PAG:statusWord,conoZeroCount,conoCount,ebPtr,ubPtr,pageEnabled,tops20Page,tlbFlushCount,dataoCount,lastDatao,currentAcBlock,previousAcBlock,previousContextSection|MEM:pages,word36,sha256`

Its SHA-256 is
`6ead1c67a795029b094fc3c381b2edfd311146aee374b196227932e0e761aa30`.

The preserved tape identity remains SHA-256
`7248864ad885ee89f4c3e93b0dfa266bfa5e79c136f3cace300480df179780f7`.

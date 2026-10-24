# MVS/TK5 3270 semantic evidence used by candidate11

This file records the evidence boundary for `MVS3270KnownStates.cls`.  It is
not a credential store and contains no password value.

## Retained live observations

The MVS Intention x3270 reference qualification retained these observations
from ED209Z / ED209ZZ:

- Hercules/TK5 attachment panel includes `Hercules Version`, `The MVS 3.8j`
  and `Tur(n)key System` before the qualified RESET/CLEAR transition.
- The real TSO logon panel includes `Logon ===>` and, on the captured TK5
  panel, `RUNNING  TK5`.
- After userid submission TK5 Update 5 presented
  `ENTER CURRENT PASSWORD FOR HERC03-`.  Terminal Machine generalises only the
  stable prompt prefix; it does not bind recognition to that userid.
- Successful authentication is evidenced only by a current screen row whose
  trimmed content is exactly `READY`.  Substrings such as `READY TO PROCESS`,
  command echo, or unrelated messages are insufficient.
- Live qualification reached the ISPF primary menu.  Candidate12 additionally
  uses the exact TK5 manual Figure 17 screen as a retained reference exemplar.
  `MVS.ISPF.PRIMARY_OPTION_MENU` therefore requires three corroborating visible
  markers from that exemplar: the title, `Option ===>`, and the END instruction.
  This does not relabel manual/reference evidence as live Terminal Machine truth.

## Authority boundary

Recognition is observation only.  These states do not authorize typing a
userid/password, pressing ENTER/PF keys, issuing TSO commands, or treating the
terminal as authoritative for Hercules process state or MVS guest semantic
state.  Mutation remains behind `TerminalSessionOwner` and
`TerminalControlGate`.

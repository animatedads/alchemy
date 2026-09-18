# Terminal Machine v0.22 candidate3

Direct-main publication authorised by the Architect on 2026-09-18 because the normal PC release path was unavailable.

Parent: `oorexx_terminal_machine_v0.21`.

Candidate3 adds the transport-independent IBM 3270 presentation-space/data-stream slice, traditional TN3270 framing/session support, PF/PA AIDs, generation-driven waits, and detached 3270 snapshots that do not expose NONDISPLAY field values.

Focused execution under ooRexx 5.3.0 r13196 passed:

- PASS 3270 DATASTREAM
- PASS 3270 AIDS
- PASS TN3270 WIRE
- PASS 3270 SNAPSHOT

The supplied candidate3 archive SHA-256 is:

`c18bbca64c14b3f0e6937e933bb317b22d46d805bbc821c4170e98297e5a8eb5`

Known next work remains standards-hardening of host READ BUFFER/READ MODIFIED responses, traditional terminal-type/TN3270E separation, SFE/SA/MF extended attributes, one overall timeout budget, semantic known-state waits, and full ownership/control-gate integration.

The 3270 engine remains transport-independent so TN3270/TN3270E and the native S/360 channel-attached 3270 adapter can share native presentation semantics without translating 3270 into TN5250.

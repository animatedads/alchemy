# FederationBank Staff Banking v0.4 delivery

v0.4 is the first Staff Banking delivery to include an early Wire UI surface.
The accepted v0.3 backend packages are unchanged; v0.4 adds
`federationbank_staff_wire_ui_v0.1`.

The UI is intentionally narrow: server-authoritative staff context, durable work
queue/detail and the first CUSTOMER transfer instruction. The UI remains outside
all authority decisions. Exact method permission is required before the server
creates a Staff Channel request; Staff Authority and Core Banking remain separate
later decisions.

For immediate visual inspection, unpack the Staff Wire UI package and run
`./start.sh`. This starts the explicitly non-authoritative preview. Live mode is
available only with an authoritative Wire UI bootstrap.

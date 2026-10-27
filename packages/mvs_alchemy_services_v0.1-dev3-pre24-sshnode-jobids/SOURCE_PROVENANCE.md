# PRE24 source provenance

PRE24 is derived from the sealed PRE23 qualification package:

- `mvs_alchemy_services_v0.1-dev3-pre23-jes-completion-gated.zip`
- SHA-256 `4b7f92672b9675d2b508cef6dbda7b01fc44a381057044304cbdf269ba783b7f`

The PRE24 delta is qualification/audit only: all managed-node remote EXEC operations
issued by the live harness now carry explicit `sshnode.sh --job-id` identifiers while
file transfer remains on the documented `sshnode.sh --transfer` path. PRE23's HASP395
and retained-final-spool gates are unchanged. No carrier, wire, RPC, provider or
authority semantics are changed.

`MANIFEST.SHA256` is the member-integrity authority. The final PRE24 archive SHA-256
is recorded externally in Library, GitHub continuity and Rasen Falcon lane records.

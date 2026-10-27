# PRE23 source provenance

PRE23 is derived byte-for-byte from the PRE22 current-contract source tree except
for the qualification-completion delta documented in `README.md` and
`QUAL/PRE23_STATIC_QUALIFICATION.txt`.

PRE22 source artifact:

- `mvs_alchemy_services_v0.1-dev3-pre22-current-contracts.zip`
- SHA-256 `3f3bed3da3f9a412de1a69f49e095382c81cfca91312c330c775bbe9afa128ea`

PRE23 changes only qualification identity/evidence and the live harness gate that
requires `$HASP395 MASLIVE ENDED` plus retained final spool after `MASLIVE PASS ALL`.
No MVS carrier, wire, RPC, provider or authority semantics are changed.

`MANIFEST.SHA256` is the member-integrity authority for this source tree.  The sealed
PRE23 archive SHA-256 is recorded externally in the Library, GitHub continuity
record and Rasen Falcon lane because an archive cannot truthfully contain its own
final hash without changing that hash.

# Rasen Falcon identity role packaging

Deployment dev5 is the first concrete Rasen Falcon role consumer of the sealed
namespace contract introduced in dev4.

The LDAP-owned component supplies the daemon bootstrap, hardened systemd unit,
configuration examples and LDAP semantics. General Deployment does not fork or
reimplement those authorities. It packages the exact LDAP tree together with an
already verified dependency namespace and changes only the process launch seam:
the generated service unit invokes `launch_oorexx_namespace.sh`, which verifies
the namespace manifest, reconstructs the exact recorded `REXX_PATH`, discards
ambient `REXX_PATH`, and then execs the LDAP bootstrap.

The current source authority used for this increment is the Library
`oorexx_ldap_identity_v0.1-dev22.zip`, SHA-256
`697c301c37ad1d77252a34db9028420c4c9a3e3dbe5c60de9be6fc91940341fc`,
plus the corrected Git handoff commit
`0495e8604c62fc780aff3c95b94c935415ffc57d` from PR #71. The role builder accepts
these identities as explicit evidence; it does not discover a newer source
implicitly.

The produced role matches the existing Rasen Falcon delivery controller shape:

- `manifest.tsv` — exact staged file hashes and destinations;
- `services.txt` — `rasenfalcon-ldap.service`;
- `tests.tsv` — `ready:ldap_bind`, `e2e:ldap_revoke`, and
  `e2e:sign_verify_revoke`;
- `files/ldap/` — the owned LDAP component plus exact dependency namespace;
- `files/systemd/rasenfalcon-ldap.service` — LDAP-owned hardening with the exact
  namespace launcher inserted;
- `files/config/*.example` — configuration shapes only, never production
  secrets; and
- `evidence/identity-role.tsv` — exact source/archive/namespace authority.

The ready probe is a real LDAPS bind plus base search using Python's standard
TLS/socket stack and runtime-injected credentials. The revoke and sign/revoke
acceptance wrappers fail `NOT_RUN` unless the corresponding owned live probes are
installed. They are deliberately not fixture PASS scripts.

This source increment does **not** install `/etc/rasenfalcon/ldap.env`, provision
principals/ACLs, issue private certificates, enable the systemd unit or perform a
production cutover. Those remain operator-gated activation inputs.

### Namespace relocation

A materialised namespace may be constructed in controller storage and later
installed under `/opt/rasenfalcon/ldap/dependency-namespace`. dev5 therefore uses
`evidence/rexx-path.relative.txt` as the portable launch projection. The namespace
manifest is verified unchanged, then the verifier/launcher reconstructs each
absolute directory from the actual installed namespace root. The dev4 absolute
`rexx-path.txt` remains provenance/backward compatibility evidence, not a reason
to retain a construction-path dependency after installation.

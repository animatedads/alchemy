# Alchemy publication parity and RasenFalcon source gates — 29 October 2026

This note supersedes the **readiness assertions**, not the immutable source hashes, in the [24 October reconciliation](ALCHEMY_DELIVERY_GITHUB_RECONCILIATION_2026-10-24.md). **Autobuilder is offline**; a submission branch and an old receipt are not acceptance of current source.

## Delivered executable source parity tool

`tools/alchemy_delivery_parity.py` compares all **owned regular file bytes**, including binary timezone data, between a single delivery ZIP and a precisely selected Git package/sphere root. It strips a single obvious top-level delivery prefix by default; use `--strip-prefix none` for already-rooted `src/` trees where required.

Example from an Alchemy checkout:

```sh
python3 tools/alchemy_delivery_parity.py \
  --archive /path/to/single_time_service_v0.9.zip \
  --destination packages/single_time_service_v0.9 --json > /tmp/single-time-parity.json
python3 -m unittest discover -s tests -p 'test_alchemy_delivery_parity.py' -v
```

Exit codes: **0** exact owned source parity, **1** missing/different/unsafe destination member, **2** audit error (bad ZIP, traversal, archive symlink, absent destination). `vendor/`, `deps/`, `dependencies/`, `third_party/`, `externals/`, `__pycache__/` and bytecode are excluded; omissions are listed in the JSON and must be resolved as independent dependency authorities. The tool is **read-only** and never creates release receipts. It does not compare code semantics or claim runtime qualification. An archive with no owned file members cannot pass.

Qualification evidence: **12 of 12 local Python unit tests PASS**, including archive path traversal, duplicate-case path, symlinks, binary bytes and errors. On `single_time_service_v0.9.zip`, comparing against a newly extracted *local fixture* returned `80 MATCH / 0 MISSING / 0 DIFFERENT / 2 excluded cache`. This was deliberately a **tool functionality check**, **not** a GitHub package parity check or ooRexx qualification.

## Current critical-service source presence (not activation)

| Critical deliverable | Exact source observed on GitHub | Gate still unresolved |
|---|---|---|
| Public Rasen Falcon website | `packages/rasenfalcon_delivery_v0.4.5/website/server/serve.rex`, `handoff/deployment/public_role_slice.py` | The v0.4.5 README explicitly says this is a **site-only**, source-hash-verified role slice; no approved native HTTPS systemd service, real TLS qualification or public release approval. |
| Owned HTTPS | `packages/oorexx_https_server/rexx/https_server.cls` and standalone v0.4.4 source; new HTTPS/WebDAV v0.4.8 qualification gate commits | Actual SNI+Host/vhost/alias binding, exact promoted source and live SNI/mTLS/negative-path tests need independent proof. |
| Native SMTP | `packages/oorexx_smtp_secure_stack/src/SmtpWireServer.cls` and durable-delivery source | Installed listener, correct MX/port, private CA, LDAP authorization, relay denial, inbox indexing and real inbound/outbound mail are **NOT VERIFIED** here. |
| Native IMAP | `packages/oorexx_imap/src/ImapServer.cls`, `ImapSession.cls` and LDAP adapter | Real authenticated IMAP over our TLS, mailbox roundtrip and persistence with SMTP remain **NOT VERIFIED**. |
| LDAP Identity Directory | `packages/oorexx_ldap_identity/src/LdapWireServer.cls`, `IdentityDirectory.cls`, Access Permissions adapter | Current package source/qualification pin, certificate and signer chain, runtime bind and fail-closed authorization still need live evidence. |
| MU↔MI transport | `packages/oorexx_xtp_v0.1-dev34/src/xtp_security.cpp`, `xtp_service.cpp`, `CAPABILITIES.json` | Commissioned MI↔own MU Layer 2 0x817D, MU↔MU raw36 or UDP fallback as appropriate; authenticated named-service FIRST/ACK, RTO2 and real independent host matrix remain separate gates. |

**Owned stack policy:** do not substitute Postfix, Dovecot, slapd, Nginx or a foreign webmail/HTTPS server. Do not infer a service is running from documentation, CI, DNS assumptions or a source package. Systemd and OpenSSL are permitted platform facilities, not application authorities. Respect private-CA-only policy and host/role separation. The public site must not route to private Office/NOC/MCP/gateway services without appropriate separate authority.

## Programme coordination and next acceptance actions

- Rasen Falcon programme coordination request `REQ-00001773` sent to `CLAUDE` on component `alchemy-programme` asking for exact critical-path commits, pending tests and integration boundaries.
- Re-check single-time service complete source, older source heads, and all high-priority October Library deliveries using the exact parity tool against a genuine Git checkout. Do not mark a row complete from a version marker or Gopher sphere.
- Publish missing source through an reviewed direct Git commit while Autobuilder is down, with tests, provenance and package-owner approval. Do not synthesize or backdate a receiver receipt.
- Host owners must execute fresh live service checks from the actual host boundary (SNI/Host mismatch, SMTP signed/unsigned/relay rejection, IMAP/LDAP bind and deny, MI/MU named-service routing and RTO2 results); record endpoints, exact revisions and command/result receipts with secrets redacted. Until then the outcome is `NOT_VERIFIED`.

Architecture owner: Tom Dyer. This source-audit and programme note: ChatGPT (GPT-6). No claim that a live server, mail queue, DNS record or ED209 host was modified by this increment.

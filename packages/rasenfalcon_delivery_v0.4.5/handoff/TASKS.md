# RasenFalcon full-stack dogfood delivery — v0.3

**Status: IMPLEMENTATION HANDOFF / NOT DEPLOYED.** Tasks are authored for Codex and independent architectural review. The Alchemy project-coordination interface required an authenticated principal. Independent GitHub issue tickets are used for implementation handoff; live Codex execution is separately qualified.

**Correction to v0.1:** Remove every Postfix, Dovecot, slapd, Nginx and third-party mail/LDAP/web runtime dependency. Deployment must reuse **our** HTTPS Server, IMAP, SMTP, LDAP Identity Directory, Wire Server, NotNotes, MCP Service, Crypto, Connect Selector, Storage Fabric and Instrumentation Mesh. If some functionality exists only as client/adapter rather than a production listener, **implement it inside the owned component line**. Do not quietly substitute another product.

## Authoritative hostname/service mapping

| Address | Intended authority and user experience | DNS/host fact |
|---|---|---|
| `rasenfalcon.com`, `www.rasenfalcon.com` | Public site served through our HTTPS server | Records/placement to confirm |
| `gateway.rasenfalcon.com` | Our SMTP/IMAP mail gateway **and** LDAP-protected Wire portal | Mail and HTTPS coexist on distinct ports; gateway IP not stated |
| `gateway.rasenfalcon.com` → `ed209zz`, `ed209z` | LDAP-gated 3270 terminal sessions via owned protocol bridge + Wire terminal screen | Target ports and network reachability to qualify |
| `gateway.rasenfalcon.com` → `ed209cray`, `ed209tops` | LDAP-gated fixed-target web access through owned HTTPS access facade | Target URL/port/TLS to qualify |
| `office.rasenfalcon.com/mail` | Wire-driven mail client backed by our IMAP/SMTP | Proposed path under user-selected hostname |
| `office.rasenfalcon.com/notes` | Wire-driven NotNotes with existing document authority | Proposed path under user-selected hostname |
| `noc.rasenfalcon.com` | HTTPS NOC alias handled via SNI/virtual-host mapping | CNAME → `london1.rasenfalcon.com` |
| `london1.rasenfalcon.com` | Canonical host of NOC DNS CNAME | A `213.255.246.44` supplied by user |
| `mcp.rasenfalcon.com` | Authenticated mail and NotNotes MCP adapters on our MCP Service | DNS explicitly user-configured, must not be silently changed |

**Do not infer** gateway, office, MCP or any ED209 target IP address from the london1 A record. The port/site mapping is an acceptance target, not a claim of current deployment.


## Codex delivery assignments — v0.3

Nine large, independently testable coding lanes have been defined in `codex/CX-01.md` through `codex/CX-09.md`. Their exact order and dependencies are in `codex/jobs.json`. These are implementation jobs, not just architecture reviews. GitHub issues [#6–#14](https://github.com/animatedads/alchemy/issues) have been opened for these nine jobs. An opened issue is not a running Codex session; execution must be separately started by the agent's actual runtime.

**Host correction (21 October 2026):** Use **ed209tops** for the second allowed gateway web access target. The authoritative gateway targets are `ed209zz`, `ed209z`, `ed209cray`, `ed209tops`.

## Classification

- `VERIFY`: locate existing accepted source and prove capabilities.
- `INTEGRATE`: deploy/compose existing owned components.
- `BUILD` / `BUILD_GAP`: code must be authored in our project; do not assume it already exists.
- `VERIFY_THEN_BUILD`: verify server-side capability is present; implement uncovered parts under the existing component authority, never substitute third-party software.
- `QUALIFY`: end-to-end live and negative testing, not static source review.
- `REVIEW`: explicit architectural/user decision gate.

## Critical sequence

Inventory and contract (RF-001–007) → HTTPS/LDAP/keys/mail core (RF-008–020) → agent MCP and Office apps (RF-021–028) → gateway 3270/web portal (RF-029–037) → production startup, security and recovery (RF-038–042) → independent real protocol acceptance (RF-043–046).

## Tasks

### RF-001 — Source/acceptance inventory of OUR components (VERIFY; Architecture; P0; phase 0)
- **Depends on:** none
- **Deliverable:** Locate accepted source, manifests and exact revision for ooRexx HTTPS Server, SMTP Secure Stack/server, IMAP server/client, LDAP Identity Directory, Wire UI Server/Builder, NotNotes, Crypto/PKI, MCP Service, Connect Selector, Deployment and 3270 or terminal modules. Produce capability matrix: implemented/tested/missing.
- **Acceptance:** Each dependency has package SHA, tested API, service entry point, owner and evidence; unverified interfaces labeled UNKNOWN rather than assumed.

### RF-002 — RasenFalcon architecture and hard dependency contract (REVIEW; Architecture; P0; phase 0)
- **Depends on:** RF-001
- **Deliverable:** Author one authority diagram and service/transport mapping. All mail, LDAP, web and MCP application semantics implemented with owned ooRexx/Alchemy modules. Systemd/OpenSSL/standard network protocols are platform support, not product substitutes.
- **Acceptance:** No Postfix, Dovecot, slapd, Nginx, third-party webmail, third-party MCP server or duplicated Wire/NotNotes authority in dependency closure.

### RF-003 — Physical host and service placement (REVIEW; Infrastructure; P0; phase 0)
- **Depends on:** RF-001
- **Deliverable:** Confirm actual OS, architecture, listener conflicts, resources and role placement for gateway, office, NOC, london1 and MCP; map 213.255.246.44 only to london1; no assumption gateway/office resolve to same IP.
- **Acceptance:** Authenticated server facts, listening ports, existing services and approved separation/backups recorded before mutations.

### RF-004 — DNS and hostname authority (INTEGRATE; Infrastructure; P0; phase 0)
- **Depends on:** RF-003
- **Deliverable:** Configure or document authoritative DNS: noc CNAME london1; london1 A 213.255.246.44; gateway mail/HTTPS; office Wire apps; MCP DNS user-managed; MX points at gateway; public apex/www. Track TTL and PTR separately.
- **Acceptance:** Independent DNS checks prove requested records. Deployment never rewrites user-managed mcp DNS; no invented IP for gateway/office.

### RF-005 — Build and pinned-component release pipeline (BUILD; Codex; P0; phase 0)
- **Depends on:** RF-001, RF-002
- **Deliverable:** Create source builds, immutable signed/hash-pinned release manifest, dependency closure, build logs, unit tests and reproducible qualification on target OS.
- **Acceptance:** Clean build only uses pinned owned components; missing package or failing module test blocks release.

### RF-006 — Installer and systemd lifecycle controller (BUILD; Codex; P0; phase 0)
- **Depends on:** RF-003, RF-005
- **Deliverable:** Implement preflight/install/apply/activate/verify/status/rollback service deployment using owned component archives. Generate units and environment files from accepted service entry points, not placeholders.
- **Acceptance:** Idempotence, reboot autorestart, explicit human activation approval and rollback; no green status without protocol end-to-end acceptance.

### RF-007 — Service contract/health-test harness (BUILD; QA; P0; phase 0)
- **Depends on:** RF-005
- **Deliverable:** Implement machine-verifiable contract tests, fixture accounts, signed acceptance evidence, timeouts, and negative tests for mail, Wire, LDAP, MCP, terminal and browser proxy.
- **Acceptance:** Every release includes non-stub tests for all mandatory capabilities, with explicit failure propagation and no synthetic PASS.

### RF-008 — HTTPS virtual hosts, aliases and SNI (BUILD_GAP; HTTPS; P0; phase 1)
- **Depends on:** RF-001, RF-004
- **Deliverable:** Enhance existing ooRexx HTTPS Server with multi-host TLS certificate selection, normalized Host/:authority handling, virtual-host map, explicit aliases, and fail-closed unknown/mismatched authority. DNS CNAME not resolved per request.
- **Acceptance:** http request to noc.rasenfalcon.com (CNAME london1) retains noc host, has valid cert and correct vhost. SNI/Host mismatch and unknown host refused with proper HTTP response such as 421.

### RF-009 — Native TLS certificate provisioning and renewal (INTEGRATE_GAP; Security; P0; phase 1)
- **Depends on:** RF-008
- **Deliverable:** Integrate ACME/certificate renewal (or accepted owned implementation) into HTTPS lifecycle; distinct identities for gateway, office, noc and mcp. TLS remains in native HTTPS server, no proxy substitution.
- **Acceptance:** Hostname validation, renewal staging, rotation without dropping sessions where supported, expired/untrusted-key negative tests.

### RF-010 — HTTPS request routing and application isolation (BUILD_GAP; HTTPS; P0; phase 1)
- **Depends on:** RF-008
- **Deliverable:** Host routing: public site on apex/www; gateway Wire portal; office /mail and /notes; mcp only separately governed routes; NOC host explicit. Prevent Host injection/open reverse proxy and cross-vhost auth/session leakage.
- **Acceptance:** Correct vhost and independent cookies/headers for each hostname and route; wrong vhost cannot access private handler.

### RF-011 — LDAP server deployment, identity schema and availability (INTEGRATE_GAP; LDAP; P0; phase 1)
- **Depends on:** RF-001, RF-003
- **Deliverable:** Deploy the accepted ooRexx LDAP Identity Directory authoritative service, accounts/groups/mail addresses, LDAPS or StartTLS, local/replica topology and recovery according to accepted contracts.
- **Acceptance:** Own LDAP server binds, search, password/revoke, group tests and restart; no slapd installed; failure denies authentication.

### RF-012 — LDAP authenticator and per-service permissions (BUILD_GAP; Identity; P0; phase 1)
- **Depends on:** RF-010, RF-011
- **Deliverable:** Implement reusable LDAP-backed authentication/session boundary for gateway Wire, office Wire, mail submission/IMAP and MCP bearer/OAuth mapping; local role checks independent of renderer.
- **Acceptance:** Allowed/denied accounts, lockout/revocation, cookie CSRF protection, anti-fixation, session logout, group changes reflected across all consumers.

### RF-013 — Owned cryptographic key issuance and signing lifecycle (BUILD_GAP; Crypto; P0; phase 1)
- **Depends on:** RF-001, RF-011
- **Deliverable:** Pin ooRexx Crypto/PKI, implement key issuance and lifecycle for TLS, SMTP DKIM, person/service message signatures and signed NotNotes, with separate keys/ACLs, HSM/provider where available.
- **Acceptance:** Issue, verify, rotate, revoke and audit work. Private keys never enter source release/MCP output; no silent authority to sign on behalf of people.

### RF-014 — Native mail gateway SMTP listener and spool (VERIFY_THEN_BUILD; SMTP; P0; phase 1)
- **Depends on:** RF-001, RF-011, RF-013
- **Deliverable:** Prove existing owned SMTP server implements inbound SMTP port 25, EHLO, STARTTLS policy, RCPT recipient validation, durable spool and local delivery hooks. Implement any missing listener/queue/DSN/retry adapters in ooRexx SMTP component.
- **Acceptance:** External unauthenticated mail to existing rasenfalcon recipient accepted and delivered; invalid RCPT and unauthorized relay rejected; crashes do not lose accepted mail.

### RF-015 — Native SMTP authenticated submission (VERIFY_THEN_BUILD; SMTP; P0; phase 2)
- **Depends on:** RF-012, RF-014
- **Deliverable:** Add/qualify port 587 submission AUTH with LDAP identity, TLS, MAIL FROM ownership, quotas, spool state and retry semantics in our SMTP service.
- **Acceptance:** Authorized per-user send works; mismatched sender, invalid bind and unauthenticated relay denied; delivery receipt/evidence recorded.

### RF-016 — Native IMAP listener and mailbox semantics (VERIFY_THEN_BUILD; IMAP; P0; phase 1)
- **Depends on:** RF-001, RF-011, RF-014
- **Deliverable:** Prove our IMAP package actually contains the server-side TCP listener and RFC IMAP4rev1/2 subset required (not merely IMAP client/service adapter); implement missing server bridge. Mailbox UIDVALIDITY, UID and persistent flags are authoritative.
- **Acceptance:** External IMAPS 993 authenticated connect/list/select/fetch/store/move works; UID identity survives restart; no Dovecot replacement.

### RF-017 — Native mailbox storage & SMTP-to-IMAP delivery (BUILD_GAP; MailStore; P0; phase 2)
- **Depends on:** RF-014, RF-016
- **Deliverable:** Connect owned SMTP delivery to owned mailbox store through accepted Storage Fabric/NoSQL contracts; enforce quotas, retention, indexes, MIME streaming and UIDVALIDITY rules.
- **Acceptance:** Accepted SMTP transaction appears in intended IMAP mailbox and not in another; transactional durability, quotas and UID proof pass.

### RF-018 — Native mail authentication, TLS and abuse controls (BUILD_GAP; MailSec; P0; phase 2)
- **Depends on:** RF-012, RF-015, RF-016
- **Deliverable:** Enforce LDAP-backed IMAP and SMTP identities, rate limits, abuse suppression, size limits, malformed MIME defenses, SPF/DKIM/DMARC integration points and delivery audit in our stack.
- **Acceptance:** Reject open relay, credential brute-force, forgery and oversized attack cases; no plaintext auth without protected transport.

### RF-019 — Mail DNS and outbound authenticity (INTEGRATE; MailDNS; P0; phase 2)
- **Depends on:** RF-004, RF-013, RF-015
- **Deliverable:** Publish validated MX gateway, SPF, DKIM selectors, DMARC and PTR coordination for gateway; TLS cert valid for mail use; key rollover policy.
- **Acceptance:** Independent inbound/outbound test identifies authenticated domain and no false DNS/PTR claims; receiver verifies DKIM.

### RF-020 — Separate ChatGPT and Claude mailbox principals (INTEGRATE; Identity; P0; phase 2)
- **Depends on:** RF-011, RF-015, RF-016
- **Deliverable:** Provision separately-scoped accounts (proposed chatgpt@ and claude@rasenfalcon.com) with isolated mailboxes, distinct credentials, rate limits and audit; client-side access only through scoped connectors.
- **Acceptance:** Each account reads/sends as itself only. Cross-principal read/send denied; disable/revoke severs access.

### RF-021 — Mail MCP service implementation (BUILD_GAP; MCP; P0; phase 2)
- **Depends on:** RF-012, RF-015, RF-016, RF-020
- **Deliverable:** Build MCP tool adapter on OUR MCP service and IMAP/SMTP APIs: inbox/folders/search/get/draft/submit, attachments with limits, status and per-account OAuth/scopes; not a separate mailbox service.
- **Acceptance:** MCP read/send test passes with each own principal; denied scope cannot send or read another mailbox; messages treated as untrusted content.

### RF-022 — ChatGPT/Claude MCP connector compatibility (QUALIFY; MCP; P0; phase 3)
- **Depends on:** RF-021, RF-009
- **Deliverable:** Validate real MCP transport/auth/tool description compatibility with currently supported ChatGPT and Claude connection flows; browser/user approval where required.
- **Acceptance:** Both clients can independently connect to own account and read/send a controlled challenge; unsupported connector features documented truthfully.

### RF-023 — Wire MailReader semantic core and IMAP source window (BUILD_GAP; WireMail; P0; phase 2)
- **Depends on:** RF-016, RF-017
- **Deliverable:** Promote MailReader fixture to real ooRexx mail application behaviour while reusing accepted Wire/Builder source/filtered windows and stable mailbox|UIDVALIDITY|UID key.
- **Acceptance:** 200k message fixture only projects bounded visible rows; actions and semantic traces identical headless and browser.

### RF-024 — office Wire webmail application (BUILD; WireMail; P0; phase 3)
- **Depends on:** RF-010, RF-012, RF-015, RF-023
- **Deliverable:** Build office.rasenfalcon.com/mail: authenticated folders, search, thread/detail, compose/reply/forward, attachments, draft, sent, accessibility/responsive; no browser-owned business truth.
- **Acceptance:** Browser receives test email, reads, replies, marks, searches and attaches; authorization checks are server-side and hostile HTML inert.

### RF-025 — NotNotes semantic service and persistence contract (INTEGRATE_GAP; NotNotes; P0; phase 2)
- **Depends on:** RF-001, RF-011, RF-012
- **Deliverable:** Qualify our NotNotes document authority, Mini App, revisioning, links, permissions, intentions, persistence and time semantics; implement any missing web-safe service adapter.
- **Acceptance:** Create/read/edit/link/unlink/revision-conflict/ACL success and denial; no second document store.

### RF-026 — office Wire NotNotes application (BUILD; WireNotes; P0; phase 3)
- **Depends on:** RF-010, RF-012, RF-025
- **Deliverable:** Build office.rasenfalcon.com/notes Wire semantic UI: document explorer, edit, links, search, permissions, versions, intentions and accessibility.
- **Acceptance:** Same semantic trace through TestRenderer and Web; editing and concurrent revision conflicts behave correctly.

### RF-027 — NotNotes MCP service (BUILD; MCP; P0; phase 3)
- **Depends on:** RF-012, RF-025
- **Deliverable:** Build on owned MCP service: list/search/read/create/update/link/unlink, intentions with per-doc ACL and optimistic concurrency preconditions.
- **Acceptance:** Denied doc access, stale revision and prompt injection cannot cause effects; auditable creation and edits succeed.

### RF-028 — Mail + NotNotes signing operations (BUILD_GAP; Crypto; P0; phase 3)
- **Depends on:** RF-013, RF-021, RF-025, RF-027
- **Deliverable:** Expose signing/verification in owned services; canonical signed content and person/service authority separation. Do not conflate DKIM with user document signing.
- **Acceptance:** Tamper, revoked key, bad signer and successful verification test matrix passes; user signature requires explicit proper authority.

### RF-029 — Gateway authenticated Wire portal (BUILD; WireGateway; P0; phase 2)
- **Depends on:** RF-010, RF-011, RF-012
- **Deliverable:** Build gateway.rasenfalcon.com as Wire ops portal listing only approved terminals and web destinations; LDAP login and group-based session grants before showing/connecting.
- **Acceptance:** Unauthenticated GET/actions deny; authenticated but unauthorized account cannot see or connect targets; logout terminates sessions.

### RF-030 — Browser 3270 protocol/session adapter (BUILD_GAP; Terminal3270; P0; phase 2)
- **Depends on:** RF-001, RF-029
- **Deliverable:** Implement or reuse an owned TN3270/TN3270E client/session library, 3270 data stream screen model, keyboard AID keys, protected fields, EBCDIC code pages, disconnect/reconnect; transport scoped, no raw browser sockets.
- **Acceptance:** Recorded fixtures and host-backed session tests prove 3270 data/keyboard fidelity; unsupported host mode is explicit error, not silent terminal emulation.

### RF-031 — Wire 3270 screen renderer and browser interaction (BUILD; Wire3270; P0; phase 3)
- **Depends on:** RF-029, RF-030
- **Deliverable:** Implement Wire semantic terminal surface with screen coordinate/grid, cursor, protected-input state, PF/PA/Enter/Clear and accessibility for web browser.
- **Acceptance:** 3270 fixture golden traces and live session have correct screen render, key events and session teardown.

### RF-032 — ed209zz TN3270 session binding (INTEGRATE_GAP; Terminal3270; P0; phase 3)
- **Depends on:** RF-030, RF-031
- **Deliverable:** Configure approved network and port for ed209zz, endpoint certificate/host authentication where supported, LDAP portal authorization and backend host sign-on distinct from portal auth.
- **Acceptance:** Authorized user can open real ed209zz session; denied users cannot; target errors and session reset handled.

### RF-033 — ed209z TN3270 session binding (INTEGRATE_GAP; Terminal3270; P0; phase 3)
- **Depends on:** RF-030, RF-031
- **Deliverable:** Configure approved network and port for ed209z, same policy, separate host target identity and protected sign-on.
- **Acceptance:** Authorized session reaches ed209z with correct terminal identity; all negative cases pass.

### RF-034 — Approved web access relay (non-open proxy) (BUILD_GAP; GatewayProxy; P0; phase 2)
- **Depends on:** RF-010, RF-012, RF-029
- **Deliverable:** Build owned HTTPS/WebSocket tunnel/reverse access facade with fixed allowlisted targets, upstream origin/header/auth isolation, WebSocket support where needed, no arbitrary URL fetch or SSRF.
- **Acceptance:** Unauthenticated, unlisted and cross-origin destinations rejected; sessions are audited and browser content isolated.

### RF-035 — ed209cray web access binding (INTEGRATE_GAP; GatewayProxy; P0; phase 3)
- **Depends on:** RF-034
- **Deliverable:** Map approved upstream URL/port and TLS trust for ed209cray through gateway authenticated Wire entry, without exposing raw target to unauthenticated internet.
- **Acceptance:** Authorized user reaches expected web UI and gets correct target; blocked group and unknown URLs denied.

### RF-036 — ed209tops web access binding (INTEGRATE_GAP; GatewayProxy; P0; phase 3)
- **Depends on:** RF-034
- **Deliverable:** Map approved upstream URL/port and TLS trust for ed209tops through gateway authenticated Wire entry.
- **Acceptance:** Authorized user reaches expected web UI; isolation, audit, logout and denied group verified.

### RF-037 — NOC HTTPS alias and operations access (INTEGRATE_GAP; NOC; P0; phase 3)
- **Depends on:** RF-008, RF-010, RF-012
- **Deliverable:** Configure noc.rasenfalcon.com CNAME london1 and decide NOC app/path mapping only from existing approved NOC design; ensure correct TLS SNI and HTTP host routing, independent of any speculative target.
- **Acceptance:** Alias and canonical addresses resolve, valid cert for requested noc hostname, correct route and denied unknown/mismatched host.

### RF-038 — Public rasenfalcon.com website (BUILD; Website; P0; phase 3)
- **Depends on:** RF-008, RF-010
- **Deliverable:** Build minimal owned HTTPS-hosted public website, branding/content approval, legal/contact route, accessibility; no external CMS or user tracking by default.
- **Acceptance:** Public site works via TLS with approved content; private service paths not accessible from apex virtual host.

### RF-039 — Hosted service startup units and dependency readiness (BUILD; Deployment; P0; phase 3)
- **Depends on:** RF-006, RF-009, RF-011, RF-014, RF-016, RF-024, RF-026, RF-027, RF-029, RF-030, RF-034
- **Deliverable:** Codex creates executable exact service entry points, systemd units, ordering, secrets files, restarts, readiness checks and operational permissions for accepted owned components.
- **Acceptance:** After reboot each service is active only when its real protocol endpoint is ready; no placeholder binary, fake healthz or blind start.

### RF-040 — Full-stack secure configuration and firewall plan (INTEGRATE; Security; P0; phase 3)
- **Depends on:** RF-003, RF-004, RF-010, RF-012, RF-018, RF-029, RF-034
- **Deliverable:** Define public 443,25,587,993 as applicable; keep LDAP/private RPC and internal 3270 access restricted; disallow unsolicited lateral access; SNI ACL, CSP, CSRF, MFA plan and audits.
- **Acceptance:** Port and route matrix is enforced; unauthenticated portal access, arbitrary proxying and LDAP exposure tests fail closed.

### RF-041 — Instrumentation and cross-service trace evidence (BUILD_GAP; Observability; P0; phase 3)
- **Depends on:** RF-017, RF-021, RF-024, RF-027, RF-029, RF-034
- **Deliverable:** Use owned Instrumentation Mesh/Log components for lifecycle, mail, session, HTTP routing, key and MCP audit with opaque correlators and no secret/message body leakage.
- **Acceptance:** Fault-injected cases observable with bounded logs; cross-system event lineage preserved and private content not emitted.

### RF-042 — Backup and disaster recovery of owned stores (INTEGRATE_GAP; Recovery; P0; phase 3)
- **Depends on:** RF-011, RF-013, RF-017, RF-025
- **Deliverable:** Own Storage Fabric snapshots for mailbox, NotNotes, LDAP and signing metadata/keys as appropriate; encrypt and perform restore exercise with identity and UID semantics.
- **Acceptance:** Restore reconstructs accepted messages/documents/accounts and revocation state; measured RPO/RTO, key isolation, audit.

### RF-043 — Mail/Office/MCP complete end-to-end trial (QUALIFY; QA; P0; phase 4)
- **Depends on:** RF-019, RF-020, RF-022, RF-024, RF-026, RF-027, RF-028, RF-039, RF-040
- **Deliverable:** Test inbound internet SMTP → our store → our IMAP → office Wire read → reply via own SMTP → agent MCP read/send → NotNotes MCP edit/sign.
- **Acceptance:** Controlled live fixtures, expected message IDs and authenticated actors; every hop traced and negative cases proved.

### RF-044 — Gateway operations real end-to-end trial (QUALIFY; QA; P0; phase 4)
- **Depends on:** RF-031, RF-032, RF-033, RF-035, RF-036, RF-037, RF-039, RF-040
- **Deliverable:** LDAP portal login → Wire target selection → real 3270 ed209zz/z → real web ed209cray/ed209tops; 403/deny, invalid session, logout and target outage tests.
- **Acceptance:** All four targets accessible only to authorized accounts and reliable disconnect/restart. No success based solely on mock fixtures.

### RF-045 — Independent reboot/upgrade/rollback qualification (QUALIFY; QA; P0; phase 4)
- **Depends on:** RF-039, RF-041, RF-042, RF-043, RF-044
- **Deliverable:** Reboot actual host, confirm auto-start/dependencies, negative tests and E2E operations; exercise failed release apply, rollback and restoration.
- **Acceptance:** Equivalent tests still pass after reboot and rollback, without permissions widening or data loss.

### RF-046 — Publication, commissioning and sign-off (REVIEW; Operations; P0; phase 5)
- **Depends on:** RF-038, RF-043, RF-044, RF-045
- **Deliverable:** Package results, exact source/version hashes, DNS/TLS/cert records, server configuration, ACLs, runbooks, on-call and human acceptance.
- **Acceptance:** One explicit ACCEPT/REJECT decision and live evidence. Never claim operational before user-approved cutover.

## Release gates

**G1 Source authority** — exact accepted package revision, actual server entrypoint, build/checksum and license for every component; no unapproved substitution.

**G2 Provisioned security** — valid TLS for requested names (including CNAME alias); LDAP principal/role authorization; key signing and revocation; no open SMTP relay or cross-user mailbox/doc access.

**G3 User-facing behaviour** — `office` Wire mail and notes, `gateway` Wire portal with both 3270 and both web targets, public site and gateway mail all work against live component services.

**G4 Agent access** — separately scoped ChatGPT and Claude MCP clients tested independently; access cannot be assumed merely because endpoint is hosted.

**G5 Reboot and data integrity** — systemd restart, crash/recovery, bounded queues/windows, backups, negative tests and release rollback.

**Deployment script install succeeded != deployment accepted.** All gates require evidence.

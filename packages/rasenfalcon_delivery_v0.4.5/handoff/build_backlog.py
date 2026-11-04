#!/usr/bin/env python3
import json
from pathlib import Path
R=[]
def add(n,title,lane,kind,phase,deps,deliverable,acceptance,priority='P0'):
  R.append(dict(id=f'RF-{n:03d}',title=title,lane=lane,kind=kind,phase=phase,depends_on=[f'RF-{i:03d}' for i in deps],deliverable=deliverable,acceptance=acceptance,priority=priority,status='TODO'))
# Phase zero, authority and discovery
add(1,'Source/acceptance inventory of OUR components','Architecture','VERIFY',0,[],
'Locate accepted source, manifests and exact revision for ooRexx HTTPS Server, SMTP Secure Stack/server, IMAP server/client, LDAP Identity Directory, Wire UI Server/Builder, NotNotes, Crypto/PKI, MCP Service, Connect Selector, Deployment and 3270 or terminal modules. Produce capability matrix: implemented/tested/missing.',
'Each dependency has package SHA, tested API, service entry point, owner and evidence; unverified interfaces labeled UNKNOWN rather than assumed.')
add(2,'RasenFalcon architecture and hard dependency contract','Architecture','REVIEW',0,[1],
'Author one authority diagram and service/transport mapping. All mail, LDAP, web and MCP application semantics implemented with owned ooRexx/Alchemy modules. Systemd/OpenSSL/standard network protocols are platform support, not product substitutes.',
'No Postfix, Dovecot, slapd, Nginx, third-party webmail, third-party MCP server or duplicated Wire/NotNotes authority in dependency closure.')
add(3,'Physical host and service placement','Infrastructure','REVIEW',0,[1],
'Confirm actual OS, architecture, listener conflicts, resources and role placement for gateway, office, NOC, london1 and MCP; map 213.255.246.44 only to london1; no assumption gateway/office resolve to same IP.',
'Authenticated server facts, listening ports, existing services and approved separation/backups recorded before mutations.')
add(4,'DNS and hostname authority','Infrastructure','INTEGRATE',0,[3],
'Configure or document authoritative DNS: noc CNAME london1; london1 A 213.255.246.44; gateway mail/HTTPS; office Wire apps; MCP DNS user-managed; MX points at gateway; public apex/www. Track TTL and PTR separately.',
'Independent DNS checks prove requested records. Deployment never rewrites user-managed mcp DNS; no invented IP for gateway/office.')
add(5,'Build and pinned-component release pipeline','Codex','BUILD',0,[1,2],
'Create source builds, immutable signed/hash-pinned release manifest, dependency closure, build logs, unit tests and reproducible qualification on target OS.',
'Clean build only uses pinned owned components; missing package or failing module test blocks release.')
add(6,'Installer and systemd lifecycle controller','Codex','BUILD',0,[3,5],
'Implement preflight/install/apply/activate/verify/status/rollback service deployment using owned component archives. Generate units and environment files from accepted service entry points, not placeholders.',
'Idempotence, reboot autorestart, explicit human activation approval and rollback; no green status without protocol end-to-end acceptance.')
add(7,'Service contract/health-test harness','QA','BUILD',0,[5],
'Implement machine-verifiable contract tests, fixture accounts, signed acceptance evidence, timeouts, and negative tests for mail, Wire, LDAP, MCP, terminal and browser proxy.',
'Every release includes non-stub tests for all mandatory capabilities, with explicit failure propagation and no synthetic PASS.')
# HTTP
add(8,'HTTPS virtual hosts, aliases and SNI','HTTPS','BUILD_GAP',1,[1,4],
'Enhance existing ooRexx HTTPS Server with multi-host TLS certificate selection, normalized Host/:authority handling, virtual-host map, explicit aliases, and fail-closed unknown/mismatched authority. DNS CNAME not resolved per request.',
'http request to noc.rasenfalcon.com (CNAME london1) retains noc host, has valid cert and correct vhost. SNI/Host mismatch and unknown host refused with proper HTTP response such as 421.')
add(9,'Native TLS certificate provisioning and renewal','Security','INTEGRATE_GAP',1,[8],
'Integrate ACME/certificate renewal (or accepted owned implementation) into HTTPS lifecycle; distinct identities for gateway, office, noc and mcp. TLS remains in native HTTPS server, no proxy substitution.',
'Hostname validation, renewal staging, rotation without dropping sessions where supported, expired/untrusted-key negative tests.')
add(10,'HTTPS request routing and application isolation','HTTPS','BUILD_GAP',1,[8],
'Host routing: public site on apex/www; gateway Wire portal; office /mail and /notes; mcp only separately governed routes; NOC host explicit. Prevent Host injection/open reverse proxy and cross-vhost auth/session leakage.',
'Correct vhost and independent cookies/headers for each hostname and route; wrong vhost cannot access private handler.')
add(11,'LDAP server deployment, identity schema and availability','LDAP','INTEGRATE_GAP',1,[1,3],
'Deploy the accepted ooRexx LDAP Identity Directory authoritative service, accounts/groups/mail addresses, LDAPS or StartTLS, local/replica topology and recovery according to accepted contracts.',
'Own LDAP server binds, search, password/revoke, group tests and restart; no slapd installed; failure denies authentication.')
add(12,'LDAP authenticator and per-service permissions','Identity','BUILD_GAP',1,[10,11],
'Implement reusable LDAP-backed authentication/session boundary for gateway Wire, office Wire, mail submission/IMAP and MCP bearer/OAuth mapping; local role checks independent of renderer.',
'Allowed/denied accounts, lockout/revocation, cookie CSRF protection, anti-fixation, session logout, group changes reflected across all consumers.')
add(13,'Owned cryptographic key issuance and signing lifecycle','Crypto','BUILD_GAP',1,[1,11],
'Pin ooRexx Crypto/PKI, implement key issuance and lifecycle for TLS, SMTP DKIM, person/service message signatures and signed NotNotes, with separate keys/ACLs, HSM/provider where available.',
'Issue, verify, rotate, revoke and audit work. Private keys never enter source release/MCP output; no silent authority to sign on behalf of people.')
add(14,'Native mail gateway SMTP listener and spool','SMTP','VERIFY_THEN_BUILD',1,[1,11,13],
'Prove existing owned SMTP server implements inbound SMTP port 25, EHLO, STARTTLS policy, RCPT recipient validation, durable spool and local delivery hooks. Implement any missing listener/queue/DSN/retry adapters in ooRexx SMTP component.',
'External unauthenticated mail to existing rasenfalcon recipient accepted and delivered; invalid RCPT and unauthorized relay rejected; crashes do not lose accepted mail.')
add(15,'Native SMTP authenticated submission','SMTP','VERIFY_THEN_BUILD',2,[12,14],
'Add/qualify port 587 submission AUTH with LDAP identity, TLS, MAIL FROM ownership, quotas, spool state and retry semantics in our SMTP service.',
'Authorized per-user send works; mismatched sender, invalid bind and unauthenticated relay denied; delivery receipt/evidence recorded.')
add(16,'Native IMAP listener and mailbox semantics','IMAP','VERIFY_THEN_BUILD',1,[1,11,14],
'Prove our IMAP package actually contains the server-side TCP listener and RFC IMAP4rev1/2 subset required (not merely IMAP client/service adapter); implement missing server bridge. Mailbox UIDVALIDITY, UID and persistent flags are authoritative.',
'External IMAPS 993 authenticated connect/list/select/fetch/store/move works; UID identity survives restart; no Dovecot replacement.')
add(17,'Native mailbox storage & SMTP-to-IMAP delivery','MailStore','BUILD_GAP',2,[14,16],
'Connect owned SMTP delivery to owned mailbox store through accepted Storage Fabric/NoSQL contracts; enforce quotas, retention, indexes, MIME streaming and UIDVALIDITY rules.',
'Accepted SMTP transaction appears in intended IMAP mailbox and not in another; transactional durability, quotas and UID proof pass.')
add(18,'Native mail authentication, TLS and abuse controls','MailSec','BUILD_GAP',2,[12,15,16],
'Enforce LDAP-backed IMAP and SMTP identities, rate limits, abuse suppression, size limits, malformed MIME defenses, SPF/DKIM/DMARC integration points and delivery audit in our stack.',
'Reject open relay, credential brute-force, forgery and oversized attack cases; no plaintext auth without protected transport.')
add(19,'Mail DNS and outbound authenticity','MailDNS','INTEGRATE',2,[4,13,15],
'Publish validated MX gateway, SPF, DKIM selectors, DMARC and PTR coordination for gateway; TLS cert valid for mail use; key rollover policy.',
'Independent inbound/outbound test identifies authenticated domain and no false DNS/PTR claims; receiver verifies DKIM.')
add(20,'Separate ChatGPT and Claude mailbox principals','Identity','INTEGRATE',2,[11,15,16],
'Provision separately-scoped accounts (proposed chatgpt@ and claude@rasenfalcon.com) with isolated mailboxes, distinct credentials, rate limits and audit; client-side access only through scoped connectors.',
'Each account reads/sends as itself only. Cross-principal read/send denied; disable/revoke severs access.')
add(21,'Mail MCP service implementation','MCP','BUILD_GAP',2,[12,15,16,20],
'Build MCP tool adapter on OUR MCP service and IMAP/SMTP APIs: inbox/folders/search/get/draft/submit, attachments with limits, status and per-account OAuth/scopes; not a separate mailbox service.',
'MCP read/send test passes with each own principal; denied scope cannot send or read another mailbox; messages treated as untrusted content.')
add(22,'ChatGPT/Claude MCP connector compatibility','MCP','QUALIFY',3,[21,9],
'Validate real MCP transport/auth/tool description compatibility with currently supported ChatGPT and Claude connection flows; browser/user approval where required.',
'Both clients can independently connect to own account and read/send a controlled challenge; unsupported connector features documented truthfully.')
# Wire and NotNotes
add(23,'Wire MailReader semantic core and IMAP source window','WireMail','BUILD_GAP',2,[16,17],
'Promote MailReader fixture to real ooRexx mail application behaviour while reusing accepted Wire/Builder source/filtered windows and stable mailbox|UIDVALIDITY|UID key.',
'200k message fixture only projects bounded visible rows; actions and semantic traces identical headless and browser.')
add(24,'office Wire webmail application','WireMail','BUILD',3,[10,12,15,23],
'Build office.rasenfalcon.com/mail: authenticated folders, search, thread/detail, compose/reply/forward, attachments, draft, sent, accessibility/responsive; no browser-owned business truth.',
'Browser receives test email, reads, replies, marks, searches and attaches; authorization checks are server-side and hostile HTML inert.')
add(25,'NotNotes semantic service and persistence contract','NotNotes','INTEGRATE_GAP',2,[1,11,12],
'Qualify our NotNotes document authority, Mini App, revisioning, links, permissions, intentions, persistence and time semantics; implement any missing web-safe service adapter.',
'Create/read/edit/link/unlink/revision-conflict/ACL success and denial; no second document store.')
add(26,'office Wire NotNotes application','WireNotes','BUILD',3,[10,12,25],
'Build office.rasenfalcon.com/notes Wire semantic UI: document explorer, edit, links, search, permissions, versions, intentions and accessibility.',
'Same semantic trace through TestRenderer and Web; editing and concurrent revision conflicts behave correctly.')
add(27,'NotNotes MCP service','MCP','BUILD',3,[12,25],
'Build on owned MCP service: list/search/read/create/update/link/unlink, intentions with per-doc ACL and optimistic concurrency preconditions.',
'Denied doc access, stale revision and prompt injection cannot cause effects; auditable creation and edits succeed.')
add(28,'Mail + NotNotes signing operations','Crypto','BUILD_GAP',3,[13,21,25,27],
'Expose signing/verification in owned services; canonical signed content and person/service authority separation. Do not conflate DKIM with user document signing.',
'Tamper, revoked key, bad signer and successful verification test matrix passes; user signature requires explicit proper authority.')
# Gateway special
add(29,'Gateway authenticated Wire portal','WireGateway','BUILD',2,[10,11,12],
'Build gateway.rasenfalcon.com as Wire ops portal listing only approved terminals and web destinations; LDAP login and group-based session grants before showing/connecting.',
'Unauthenticated GET/actions deny; authenticated but unauthorized account cannot see or connect targets; logout terminates sessions.')
add(30,'Browser 3270 protocol/session adapter','Terminal3270','BUILD_GAP',2,[1,29],
'Implement or reuse an owned TN3270/TN3270E client/session library, 3270 data stream screen model, keyboard AID keys, protected fields, EBCDIC code pages, disconnect/reconnect; transport scoped, no raw browser sockets.',
'Recorded fixtures and host-backed session tests prove 3270 data/keyboard fidelity; unsupported host mode is explicit error, not silent terminal emulation.')
add(31,'Wire 3270 screen renderer and browser interaction','Wire3270','BUILD',3,[29,30],
'Implement Wire semantic terminal surface with screen coordinate/grid, cursor, protected-input state, PF/PA/Enter/Clear and accessibility for web browser.',
'3270 fixture golden traces and live session have correct screen render, key events and session teardown.')
add(32,'ed209zz TN3270 session binding','Terminal3270','INTEGRATE_GAP',3,[30,31],
'Configure approved network and port for ed209zz, endpoint certificate/host authentication where supported, LDAP portal authorization and backend host sign-on distinct from portal auth.',
'Authorized user can open real ed209zz session; denied users cannot; target errors and session reset handled.')
add(33,'ed209z TN3270 session binding','Terminal3270','INTEGRATE_GAP',3,[30,31],
'Configure approved network and port for ed209z, same policy, separate host target identity and protected sign-on.',
'Authorized session reaches ed209z with correct terminal identity; all negative cases pass.')
add(34,'Approved web access relay (non-open proxy)','GatewayProxy','BUILD_GAP',2,[10,12,29],
'Build owned HTTPS/WebSocket tunnel/reverse access facade with fixed allowlisted targets, upstream origin/header/auth isolation, WebSocket support where needed, no arbitrary URL fetch or SSRF.',
'Unauthenticated, unlisted and cross-origin destinations rejected; sessions are audited and browser content isolated.')
add(35,'ed209cray web access binding','GatewayProxy','INTEGRATE_GAP',3,[34],
'Map approved upstream URL/port and TLS trust for ed209cray through gateway authenticated Wire entry, without exposing raw target to unauthenticated internet.',
'Authorized user reaches expected web UI and gets correct target; blocked group and unknown URLs denied.')
add(36,'ed209tops web access binding','GatewayProxy','INTEGRATE_GAP',3,[34],
'Map approved upstream URL/port and TLS trust for ed209tops through gateway authenticated Wire entry.',
'Authorized user reaches expected web UI; isolation, audit, logout and denied group verified.')
add(37,'NOC HTTPS alias and operations access','NOC','INTEGRATE_GAP',3,[8,10,12],
'Configure noc.rasenfalcon.com CNAME london1 and decide NOC app/path mapping only from existing approved NOC design; ensure correct TLS SNI and HTTP host routing, independent of any speculative target.',
'Alias and canonical addresses resolve, valid cert for requested noc hostname, correct route and denied unknown/mismatched host.')
add(38,'Public rasenfalcon.com website','Website','BUILD',3,[8,10],
'Build minimal owned HTTPS-hosted public website, branding/content approval, legal/contact route, accessibility; no external CMS or user tracking by default.',
'Public site works via TLS with approved content; private service paths not accessible from apex virtual host.')
# deployment and acceptance
add(39,'Hosted service startup units and dependency readiness','Deployment','BUILD',3,[6,9,11,14,16,24,26,27,29,30,34],
'Codex creates executable exact service entry points, systemd units, ordering, secrets files, restarts, readiness checks and operational permissions for accepted owned components.',
'After reboot each service is active only when its real protocol endpoint is ready; no placeholder binary, fake healthz or blind start.')
add(40,'Full-stack secure configuration and firewall plan','Security','INTEGRATE',3,[3,4,10,12,18,29,34],
'Define public 443,25,587,993 as applicable; keep LDAP/private RPC and internal 3270 access restricted; disallow unsolicited lateral access; SNI ACL, CSP, CSRF, MFA plan and audits.',
'Port and route matrix is enforced; unauthenticated portal access, arbitrary proxying and LDAP exposure tests fail closed.')
add(41,'Instrumentation and cross-service trace evidence','Observability','BUILD_GAP',3,[17,21,24,27,29,34],
'Use owned Instrumentation Mesh/Log components for lifecycle, mail, session, HTTP routing, key and MCP audit with opaque correlators and no secret/message body leakage.',
'Fault-injected cases observable with bounded logs; cross-system event lineage preserved and private content not emitted.')
add(42,'Backup and disaster recovery of owned stores','Recovery','INTEGRATE_GAP',3,[11,13,17,25],
'Own Storage Fabric snapshots for mailbox, NotNotes, LDAP and signing metadata/keys as appropriate; encrypt and perform restore exercise with identity and UID semantics.',
'Restore reconstructs accepted messages/documents/accounts and revocation state; measured RPO/RTO, key isolation, audit.')
add(43,'Mail/Office/MCP complete end-to-end trial','QA','QUALIFY',4,[19,20,22,24,26,27,28,39,40],
'Test inbound internet SMTP → our store → our IMAP → office Wire read → reply via own SMTP → agent MCP read/send → NotNotes MCP edit/sign.',
'Controlled live fixtures, expected message IDs and authenticated actors; every hop traced and negative cases proved.')
add(44,'Gateway operations real end-to-end trial','QA','QUALIFY',4,[31,32,33,35,36,37,39,40],
'LDAP portal login → Wire target selection → real 3270 ed209zz/z → real web ed209cray/ed209tops; 403/deny, invalid session, logout and target outage tests.',
'All four targets accessible only to authorized accounts and reliable disconnect/restart. No success based solely on mock fixtures.')
add(45,'Independent reboot/upgrade/rollback qualification','QA','QUALIFY',4,[39,41,42,43,44],
'Reboot actual host, confirm auto-start/dependencies, negative tests and E2E operations; exercise failed release apply, rollback and restoration.',
'Equivalent tests still pass after reboot and rollback, without permissions widening or data loss.')
add(46,'Publication, commissioning and sign-off','Operations','REVIEW',5,[38,43,44,45],
'Package results, exact source/version hashes, DNS/TLS/cert records, server configuration, ACLs, runbooks, on-call and human acceptance.',
'One explicit ACCEPT/REJECT decision and live evidence. Never claim operational before user-approved cutover.')

root=Path('/mnt/data/rasenfalcon_delivery_v0.2')
obj={'project':'rasenfalcon.com','version':'0.2','status':'PLANNED_NOT_DEPLOYED','scope':'Full-stack dogfood; use owned ooRexx/Alchemy components','architecture_rules':['No Postfix, Dovecot, slapd, Nginx, commercial webmail, third-party MCP authority','Own IMAP/SMTP/LDAP servers must be used; verify inbound listeners instead of assuming from client library description','Wire renderer presentation only; ooRexx owns behavior; NotNotes authority remains original','CNAME is DNS indirection; HTTPS routes based on requested Host/SNI and explicit aliases','Gateway Wire portal LDAP-gated; backend 3270 and web target auth remains independently enforced','No invented endpoint addresses, backend ports, target capabilities or successful tests','Signing key roles separately scoped; no private key in repo','Do not publish unapproved mcp.rasenfalcon.com DNS','No release is operational until real end-to-end protocol tests pass'], 'tasks':R}
(root/'tasks.json').write_text(json.dumps(obj,indent=2)+'\n')
head='''# RasenFalcon full-stack dogfood delivery — v0.3

**Status: PLANNED / NOT DEPLOYED.** Tasks are authored for Codex and independent architectural review. The project-coordination interface was inaccessible without an authenticated principal, so these have **not** been posted as project tickets.

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

'''
with (root/'TASKS.md').open('w') as f:
 f.write(head)
 for t in R:
  f.write(f"### {t['id']} — {t['title']} ({t['kind']}; {t['lane']}; {t['priority']}; phase {t['phase']})\n")
  f.write(f"- **Depends on:** {', '.join(t['depends_on']) if t['depends_on'] else 'none'}\n")
  f.write(f"- **Deliverable:** {t['deliverable']}\n")
  f.write(f"- **Acceptance:** {t['acceptance']}\n\n")
 f.write('''## Release gates

**G1 Source authority** — exact accepted package revision, actual server entrypoint, build/checksum and license for every component; no unapproved substitution.

**G2 Provisioned security** — valid TLS for requested names (including CNAME alias); LDAP principal/role authorization; key signing and revocation; no open SMTP relay or cross-user mailbox/doc access.

**G3 User-facing behaviour** — `office` Wire mail and notes, `gateway` Wire portal with both 3270 and both web targets, public site and gateway mail all work against live component services.

**G4 Agent access** — separately scoped ChatGPT and Claude MCP clients tested independently; access cannot be assumed merely because endpoint is hosted.

**G5 Reboot and data integrity** — systemd restart, crash/recovery, bounded queues/windows, backups, negative tests and release rollback.

**Deployment script install succeeded != deployment accepted.** All gates require evidence.
''')
print('Wrote',len(R),'tasks')

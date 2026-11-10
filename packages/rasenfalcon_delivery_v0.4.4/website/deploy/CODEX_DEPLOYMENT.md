# Rasen Falcon deployment plan — owned Alchemy stack only

**Do not treat this file as activation approval.** No live Rasen Falcon machine was modified in preparing this delivery.

## Stage 0 — Verify facts and authority

1. Inspect the active host's OS, architecture, available resources, running services, actual listener ports, and registered ooRexx package paths. Do not assume `gateway`, `office`, `noc`, `mcp`, or London1 share an IP. `london1.rasenfalcon.com` = `213.255.246.44` was stated separately from the apex/www deployment target.
2. Resolve pinned ooRexx HTTPS server and native Foreign Runtime through Runtime Registry. The inspected public site adapter targets HTTPS Server v0.4.7 and ooRexx r13196, but must be requalified against the intended live accepted revision.
3. **RF-008/RF-010 are blocking:** the existing task plan specifically calls out multi-SNI/virtual-host matching, explicit aliases, Host mismatch isolation and correct identity per host. `www` and apex must route only to this public app; private `gateway`, `office`, `mcp` and `noc` handlers must remain independent. Do not place a third-party reverse proxy as a substitute.
4. Determine real publishing and privacy approvers. Candidate content/brand is not approved; do not treat a successful technical build as legal or institutional publication authority.

## Stage 1 — Rebuild and acceptance

```bash
python3 tools/site.py validate
python3 -m unittest discover -s tests -v
python3 tools/site.py build
python3 tools/site.py status
```

Preview must serve only on loopback and use an explicit (local) certificate/key and installed bridge path, e.g. set `RF_HTTPS_BRIDGE_DIR` from the actual package location, ensure `REXX_PATH` includes the published HTTPS and Foreign Runtime packages and run `rexx server/serve.rex CERT KEY 8443`. This is not an Internet commissioning recipe; it is a developer-local smoke test.

## Stage 2 — Content and brand approval

- Resolve CMS Brand Builder's actual accepted API and approval event contract before writing an adapter.
- Map content resource proposals to genuine CMS/resource publications. Obtain exact SHA-512 Resource Editor receipts for display resources (do not reuse preview SHA-256 as an authoritative Wire ref).
- Compile/test a separate Wire authoring/admin release with an accepted exact version/dependency closure. Keep public site independent from the private admin Wire runtime.
- After actual editorial/brand/privacy approval, record the per-page exact digest/identity in `content/approvals.json`. The CLI's gate checks digest freshness and nonempty attribution, not cryptographic signatures.
- Run `python3 tools/site.py build --mode production`; a failure means the site is **not** publishable. Inspect immutable build manifest and the new sitemap/robots output. Bind the release to a pinned installation destination and prepare rollback.

## Stage 3 — Native HTTPS service integration

- Register exact GET/HEAD resource handlers in the owned ooRexx HTTPS server. Configure only apex/www virtual-host authority for public pages; require a valid cert/SNI and Host match. Do not permit private routes on the public authority.
- Stage with unprivileged service account, read-only published site directory, bounded worker admission, independent logging/retention controls, pinned TLS keys outside the source tree, and audited startup/rollback.
- Set security headers at the server boundary, supply appropriate cache policy, and verify unknown paths fail closed. Enable HSTS only after valid and correct certificate routing has been independently qualified.
- Verify `www` and apex independently, including certificate names and SNI/Host negative tests. A redirect or alias decision must be explicit, not inferred from DNS CNAME at runtime.

## Stage 4 — Independent checks

Run `deploy/site_contract_probe.sh https://rasenfalcon.com` only after approved activation, and separately for `https://www.rasenfalcon.com` if supported. Check desktop/mobile accessibility, certificate renewal, HTTP method abuse, content freshness, audit trails, page assertions and rollback. Confirm public pages do not expose editor, mail, MCP, NotNotes or NOC routes.

**Never claim that an unpublished preview has been deployed.**

# Adopted Website Builder v0.1 — public branch

Archive: `inputs/rasenfalcon_website_builder_v0.1.zip`, pinned at `public_site/builder.lock.json`. This is a complete editable preview **already produced**, not a new task to recreate the design.

## Contents and disposition

- Nine drafted pages: Home, Alchemy, Visualisation, Audio Analysis, Video Analysis, Secure Protocols, Intelligent Software, Enquiries and Privacy.
- Editorial source `content/pages/*.json`, site identity and navigation `content/site.json`.
- Machine-operable JSON CLI `tools/site.py` for validate, show, edit, build; content SHA-256 concurrency and a **per-page digest approval gate** for production.
- Preview HTML/CSS/JS, responsive layout, local assets, source lock, native owned ooRexx HTTPS v0.4.7 `server/serve.rex`, candidate CMS export, Wire semantic fixture and runbook.
- Site is visually cream/wattle/botanical, with headline **Systems that understand intention.** There is no government impersonation.

Independent local rerun: 9/9 `tests/test_site.py` PASS. `tools/site.py validate` returns `ok=true`, `page_count=9`. `tools/site.py build --mode production` correctly denies because required content approvals are absent. No runtime HTTPS, DNS, CMS/Brand Builder, Wire editor or real contact mailbox qualification was completed here.

## Required integration not yet complete

1. Establish accepted CMS Brand Builder **real executable** API and responsible publication authority. No invented interface or fake resource receipts.
2. Publish immutable Wire Resource Editor resources and capture their actual SHA-512 receipts; source preview's SHA-256s are **not** valid Wire publication receipts.
3. Compile Wire authoring/editor workflow on approved versions, verify browser/semantic trace, secure publishing and stale-edit/approval revocation.
4. Qualify native v0.4.7 HTTPS source against the repo's actual accepted source provenance; its own README shows optional mTLS, but no evidence of approved SNI/vhost runtime. CX-02 supplies Host/SNI isolation and tests.
5. Bind public apex/www **only** to public-page routes. Never expose Office, NOC, gateway, LDAP, SMTP/IMAP or MCP capabilities via the public instance.
6. Obtain brand, legal, privacy and per-page approval; verify enquiry recipient before enabling submission. Do not fake contact endpoints.
7. Run full real acceptance before approved cutover. No background/public service is installed by this package.

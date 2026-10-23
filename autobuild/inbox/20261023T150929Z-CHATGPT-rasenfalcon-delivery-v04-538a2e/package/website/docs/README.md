# Rasen Falcon public website — design delivery 0.1

**Build status:** running offline site compiler + nine complete preview pages. **Publication status:** design candidate, not deployed. This does not represent a commissioned rasenfalcon.com listener.

## Purpose

Rasen Falcon is the public home for Project Alchemy, not a library of internal component ZIPs. The visual identity is austere: cream paper, muted wattle, charcoal green, original abstract botanical mark, small masthead, generous editorial typography. No reference to an actual government department or use of a Commonwealth coat of arms is implied. No unapproved slogan, legal entity, historic establishment date or commercial price is claimed.

## Coverage

Home; Alchemy; Visualisation; Audio Analysis; Video Analysis; Secure Protocols; Intelligent Software; Enquiries; Privacy. All nine have full copy, internal links, metadata and responsive layout. CSS and JavaScript are local; there are no trackers, cookie banners, external fonts or fake forms. Preview explicitly sets noindex and disallows crawling.

## Operate as an agent or human

```
python3 tools/site.py status
python3 tools/site.py show audio-analysis
python3 tools/site.py validate
python3 tools/site.py build
python3 tools/site.py set visualisation intro "New editorial text" --expect-sha256 SHA_FROM_SHOW
python3 tools/site.py set-section audio-analysis 0 body "Revised paragraph" --expect-sha256 SHA_FROM_SHOW
python3 -m unittest discover -s tests -v
python3 tools/site.py build --mode production  # intentional failure until approved
```

The `set` and `set-section` commands support an optional optimistic-concurrency `--expect-sha256` guard and update only whitelisted fields and marks page `candidate` so an old approval cannot silently survive a content edit. New sections/pages can be added via `content/pages/*.json` with the same schema (validation checks related targets, page fields and navigation). All CLI commands emit JSON and meaningful exit codes. Run `build` after editing.

For local offline preview, open `site/index.html` in a web browser. The site can be copied to a target directory for its HTML/CSS/JS bytes; this is not authority to activate public DNS/TLS.

## Owned native ooRexx HTTPS route binding

`server/serve.rex` registers **only explicit GET/HEAD paths** with the existing `.HttpsServer` API. It intentionally binds **127.0.0.1 only** and requires the HTTPS server package plus exact Foreign Runtime dependency and certificates supplied by the deployment owner. The bridge path must be provided as `RF_HTTPS_BRIDGE_DIR` for the exact installed server version; use the existing Runtime Registry when deployment integration is qualified. Do not use this preview entry point as public Internet deployment: RF-008 virtual-host/SNI and RF-010 isolation work remain gating.

## Relevant source packages inspected

| Package | Version | Use |
|---|---|---|
| Wire UI Builder | 0.12-dev1 | Typed semantic authoring; explicit immutable release |
| Wire UI Server | 0.17.1 | Authoritative state and Wire projection |
| Alchemy Wire UI JS | 0.4-dev6 | Browser runtime for governed interactions |
| Wire UI Resource Editor | 0.3 | Resource bytes and published SHA-512 reference authority |
| ooRexx HTTPS Server | 0.4.7 | Native TLS server and route registration |
| ooRexx | 5.3.0 r13196 debug | Supplied compiler/runtime baseline |

The installed package names above are discovery evidence, **not** a proven runtime dependency closure. The site uses no third-party web server at runtime; the Python CLI is solely an offline development authoring compiler. See `integrations/CMS_WIRE_BRIDGE.md`.

## Engineering and publishing gates

1. Locate/accept the CMS Brand Builder executable contract. Do not invent its API from a commercial plan.
2. Publish CMS content resources through accepted editor and obtain exact content addresses.
3. Compile/qualify the authoring Wire project with the pinned, installed Alchemy dependency graph and verified ooRexx runtime.
4. Obtain explicit approvals for every page and brand identity. `content/approvals.json` format per page: `{ "approved_by": "...", "approved_at": "ISO-8601", "content_sha256": "..." }`; this is a simple release-policy gate, **not** a cryptographic signature or substitute for institutional identity governance.
5. Qualify native HTTPS virtual host and TLS certificates for apex/www and confirm actual DNS/placement. Preserve gateway/office/noc/mcp application isolation.
6. Verify real contact mailbox/authentication before offering contact submission, then revise privacy and data-retention disclosures.

This package deliberately does not install, start, or modify any live host.

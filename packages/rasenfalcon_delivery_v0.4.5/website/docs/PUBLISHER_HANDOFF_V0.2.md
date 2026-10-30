# Website Publisher → Rasen Falcon Builder: offline candidate handoff (v0.2)

**Source boundary:** Alchemy Website Publisher v0.3, exported `alchemy.website.publisher.export/0.1`, or a read-back `alchemy.website.publisher.native-record/0.2` from its ooRexx NoSQLServer v0.90 development adapter. The browser is not an API client to the public site and holds no deployment credentials.

## Operator commands

From the `website/` directory:

```sh
python3 tools/site.py stage-publisher /private/editorial-export.json /private/rasen-candidate-001
python3 tools/site.py build --mode preview \
  --content-dir /private/rasen-candidate-001/content \
  --output-dir /private/rasen-preview-001
```

The output contains the original site configuration, nine validated candidate page JSON files, and `staging.json`. Input bytes and each normalized candidate page have SHA-256 identities. A NoSQLServer revision number from the wrapper is recorded but **not authenticated**; no approval, author, time attestation, revision ownership, database credentials or Wire references are inferred. The handoff never modifies the authoritative checkout's `content/`, the browser draft, the database, or the original preview tree.

## Rejection and authority

- All nine slugs must match exactly. Only owned editorial fields are carried; the page's `status` is set to `candidate` and claimed extra approval fields are rejected.
- The export must have schema `alchemy.website.publisher.export/0.1`, matching `site=rasenfalcon.com`, `authority=CANDIDATE_ONLY`, and an unsigned JS-safe integer revision. Native wrappers must have the exact candidate provider/backend/authority markers and a positive native revision.
- Duplicate JSON object keys, invalid page identities, unsupported fields, broken sections/related links, excessive (>3 MB) payloads and reused staging/output directories are rejected. Staging is assembled in a private sibling temporary directory and renamed only after validation.
- Explicit output paths are never recursively deleted. Preview pages remain `noindex,nofollow` and `robots.txt` disallows crawling.
- **Production always fails closed.** A local digest, a native revision, a prepared review request or `approved` text cannot replace authenticated CMS/Brand/Wire release receipts and owner authorisation.

## Qualification and remaining work

The source-only test suite checks valid export and native wrapper, strict normalization, negative paths, atomic staging and non-destructive preview. It also parses actual Website Publisher v0.3 `reference/rasenfalcon.js` as an interoperability fixture and renders all nine pages. This is *offline* editorial import, not an authenticated CMS service.

Pending separate owner work: implemented and qualified native CMS candidate CRUD; authoritative revision/identity/approval binding; Connect Selector transport; Brand claim evidence; Wire resource release receipts; native HTTPS/SNI and revocation negative tests; deployment and rollback qualification. Do not expose the staging CLI as an unauthenticated HTTP endpoint.

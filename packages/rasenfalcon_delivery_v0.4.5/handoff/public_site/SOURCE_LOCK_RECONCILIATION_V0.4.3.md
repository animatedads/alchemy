# Rasen Falcon website — current-source lock reconciliation v0.4.3

Date: 2026-10-28. Area: `rasenfalcon-website`. Scope: development source and qualification, **not** public release.

## Independent failure corrected

Rasen Falcon v0.4.2 passed 18/18 site tests, but an independent CLAUDE-PC run reported 12/13 handoff/security tests passed: `test_exact_website_source_lock` rejected `website/docs/QUALIFICATION.md` because the website had evolved and the lock still described the original builder distribution.

The original `rasenfalcon_website_builder_v0.1.zip` SHA-256 is deliberately retained unchanged in `source_archive_sha256` as historical archive identity. The `files_sha256` map now hashes **the complete current owned website source** (28 files), including the new Publisher handoff and v0.4.2 qualification documents and the altered compiler and test files. The generated `website/site/` preview is intentionally excluded. This updated file map is not a signature, review approval or evidence that the original builder archive equals the candidate tree.

## Repeatable source lock command

From the package root:

```sh
python3 handoff/tools/website_source_lock.py check
# After a reviewed source modification, explicitly refresh (never silently during build):
python3 handoff/tools/website_source_lock.py refresh
python3 handoff/tools/website_source_lock.py check
```

The source lock verifier detects untracked, removed, changed and symlinked source; its explicit refresh preserves the pinned original archive identity, private-service policy and NOT_QUALIFIED/NOT_RUN status. Refresh is an intentional version-control change, never invoked by public site runtime or release gate. It does not confer CMS/Wire/Brand authority.

## Scope and evidence

Local qualification on recreated v0.4.2 source: `website/tests` 18/18 PASS, `handoff/tests` **21/21 PASS** (the original 13 plus eight source-lock regression tests). `website/tools/site.py` production remains DENIED pending authenticated CMS/Brand/Wire release receipts. No live HTTPS, native CMS, NoSQLServer, Wire resource release or certificate qualification was performed.

The Library contains Alchemy Website Publisher v0.4 with a native NoSQLServer v0.90 candidate. Its readme explicitly labels native tests NOT_RUN in that release environment. NoSQLServer v0.90 remains the separate development pin for the Publisher; neither Publisher v0.4 nor NoSQLServer v0.91 is silently upgraded to an accepted production dependency here.

Mailbox evidence: `rasenfalcon-website` lane; independent test request REQ-00000943 and CLAUDE-PC result REQ-00001007. The post-fix suite is a separate local requalification and still requires independent confirmation through the project process.

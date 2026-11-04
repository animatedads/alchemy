# One-command private Rasenfalcon preview pipeline (v0.4 continuation)

The independently owned Rasenfalcon v0.2 site builder is called **unchanged**, not copied into Website Publisher. The pipeline composes its `stage-publisher` and `build --mode preview` operations and checks the generated artefact before exposing it under a new output directory.

```sh
python3 tools/preview_pipeline.py \
  --candidate /private/rasenfalcon-publisher-handoff.json \
  --builder /path/to/rasenfalcon_site_v0.2 \
  --output /private/preview-candidate-001
```

Output contains `staged/`, `preview/` (nine noindex/nofollow pages, robots `Disallow: /`) and `publisher-preview-receipt.json`. Receipt carries source, staging and build hashes, but **no authenticated CMS or Wire release receipts**. The pipeline cannot publish or deploy. It refuses symlinked inputs, existing outputs, forged approval fields and production builds. It uses a private working directory and only renames it into place after verification. A single operator must reserve a unique output name; there is no cross-process rename-exclusion guarantee in this development tool.

The pipeline is local Python 3 standard-library operator tooling, **not** the runtime CMS or website backend. No HTTP server, Python `sqlite3`, service credentials or live DNS changes are involved. Production runtime remains ooRexx and NoSQLServer as explicitly pinned; release remains with the Rasenfalcon/Wire/LDAP/HTTPS owners.

Qualification: `python3 tests/test_preview_pipeline.py --builder /path/to/rasenfalcon_site_v0.2`. This test uses the real browser export, builder stage and preview, digest verification and negative cases. It does not qualify the RexxOS server or deployment.

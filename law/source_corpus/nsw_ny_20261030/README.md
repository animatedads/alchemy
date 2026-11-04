# NSW, Australian Commonwealth and New York sources, 2026-10-30

Architecture: Tom Dyer. Fetch script and runbook: ChatGPT (GPT-6), `law/tools/acquire_nswny_statutes.py`, `law/tools/OFFENCE_LAW_003_RUNBOOK.md`. The script was run by Tom Dyer. The four sources it could not get were obtained by Tom Dyer (the NSW XML) and by Claude (Opus 5.5) in the desktop app's browser pane (the NYC pages). Assembled and committed by Claude (Opus 5.5), on Tom's instruction.

- `source_manifest.json`, `acquire.log`, `verify.log`: the script's run, as it left them. Its verifier reports FAIL by design: four 403s, so the manifest is marked incomplete. Every one of its 40 files matches its SHA-256 and byte count (re-run 2026-10-30).
- `ADDITIONS_MANIFEST.json`: the eight files added afterwards (NYC Admin Code §§ 20-386, 20-387, 20-393 and 20-401; Crimes Act 1900, Crimes (Domestic and Personal Violence) Act 2007, Home Building Act 1989 and its legislative history, all NSW XML), with hash, size, how each was obtained, and version.
- **The six `us/federal/USC*.html` files are redirect pages, not statutes.** Each is 287–293 bytes, "Redirecting to the current edition". The script logged them as FETCHED and the verifier passes them, because their hashes match. The statute text is in `us/federal/edition_119-136/` (its own manifest).
- **The NSW Crimes Act file is the version valid 1–28 October 2026**, not the current one.
- **The amlegal (NYC) pages differ on every fetch:** two fetches of the same URL gave two hashes at the same size. The hash pins these bytes, not the page.

Nothing here has had its section boundaries reviewed (`section_text_verified: false`), and nothing is checked against the date of any event. These are sources, not rule packs.

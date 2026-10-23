# Rasen Falcon / Alchemy public website suite — v0.1.0 candidate

Contains the independently authored Rasen Falcon Website Builder v0.1, the Alchemy Website Publisher v0.2 candidate, and a source-only integration wrapper for managed Autobuild. This is a **reviewable source submission**, not a live site release.

## Paths

- `website/`: nine-page responsive site, JSON content source, deterministic static compiler, ooRexx HTTPS adapter, Wire fixture and site tests.
- `publisher/`: browser-based editorial preview/review/export tool, ooRexx NoSQLServer editorial snapshot store adapter, tests and source contracts.
- `docs/`: exact source hashes, authority boundary and qualification notes.

## Local verification

`python3 tests/test_suite.py` (runs original website and publisher suites)

`python3 website/tools/site.py --help` (website compiler/editing interface)

Open `publisher/index.html` locally for the publisher candidate UI. It uses a file-to-native-CLI handoff; it is **not** a network CMS service.

## Publication authority

Public DNS, HTTPS/SNI, CMS authorization, Wire resource publishing, identity and live deployment are distinct review-gated responsibilities. Uploading source to GitHub never approves a page or publishes rasenfalcon.com.

## Dependency policy

NoSQLServer, ooRexx, Wire and HTTPS server sources/binaries are NOT bundled or adopted into this component; use their separately accepted packages. Publisher v0.2's native code was aligned to NoSQLServer v0.89. v0.90 was located in the Library and is reviewed in `docs/NOSQL_V090_REVIEW.md` but is **not asserted compatible without an ooRexx integration run**.

Source provenance and qualification: `docs/PROVENANCE.json`, `docs/STATUS.md`.

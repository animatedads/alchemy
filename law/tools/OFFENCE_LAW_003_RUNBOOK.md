# OFFENCE-LAW-003 — runnable NSW + Queens statutory corpus work order

Requested 2026-10-30. Architecture Tom Dyer; source-acquisition runbook ChatGPT GPT-6. Executor: one of CLAUDE-PC / CODEX-PC (CLAUDE-PC selected). Not an offence determination or historical applicability certificate.

## Coverage

Queens / New York: New York Penal Law sections 105.00,105.05,105.20,135.60,135.65,145.00,145.10,155.05,155.20,155.30,155.35,155.40,170.10,170.25,190.25,190.40,190.42,190.60,190.65,190.78,190.80,190.81,260.31,260.32,260.34; Banking Law 14-a and 340; General Obligations Law 5-501; General Business Law 349; NYC Administrative Code 20-386, 20-387, 20-393, 20-401; US Code title 18 sections 371,641,1028A,1343,1344 and title 42 section 408.

NSW: Crimes Act 1900 sections 117,192B,192C,192D,192E,192G,192I,192J,192K,193B,195,249K,249L,249M,249N,249O,253,254,255; Home Building Act 1989 section 4; Crimes (Domestic and Personal Violence) Act 2007 sections 7 and 13. Federal Australia: National Consumer Credit Protection Act 2009 section 29 and Schedule 1 National Credit Code sections 4,5,6,32A,32B,140,155; Social Security (Administration) Act 1999 sections 58,215,216,217; Criminal Code Act 1995 (Cth) sections 11.5,134.2,135.4; Competition and Consumer Act 2010 Schedule 2 (ACL) sections 18,21,151.

The downloader captures official PDF/HTML originals and their searchable full-text projections, source SHA-256, origin URL, redirect and timestamp. **A successful download is not a verified legal section extraction.** For whole-Act sources manually extract each requested section including ALL subsections, definitions, penalties, exceptions and operative cross-references; compare boundaries against the original. Keep current and historic text distinct. Cite original Act and compilation/version. The facts and EV01–EV15 case graph must not be rewritten.

## 1. Acquire and verify locally (commands exact)

Run in approved estate checkout, not a live service; Autobuilder is OFF.

~~~sh
set -euo pipefail
cd /home/hc3/alchemy-autobuild/repo
git rev-parse --show-toplevel
git status --short
command -v python3
command -v pdftotext
python3 -m py_compile law/tools/acquire_nswny_statutes.py law/tools/verify_nswny_statutes.py

mkdir -p /home/hc3/alchemy-autobuild/legal-sources-20261030
python3 law/tools/acquire_nswny_statutes.py \
  --jurisdiction all \
  --out /home/hc3/alchemy-autobuild/legal-sources-20261030 \
  2>&1 | tee /home/hc3/alchemy-autobuild/legal-sources-20261030/fetch.log

python3 law/tools/verify_nswny_statutes.py \
  --manifest /home/hc3/alchemy-autobuild/legal-sources-20261030/source_manifest.json
~~~

The collector is source-only and may find unavailable/changed official page locations. It returns nonzero on partial acquisition and writes individual errors; report failures. Do not alter URL or content without recording corrected source in manifest. Some Australian fixed compilation URLs are intentionally date-pinned; verify as-at date and whether the correct section is in that volume before relying on it.

If the supported Computer/Git intention is blocked (e.g. SSH owner-permission error), STOP and report actual error. Never bypass a mandated gate. Existing identical source files in approved GitHub paths should be reused by raw SHA rather than uploaded twice.

## 2. Required provision-level review

For each source_manifest.json entry and requested_sections item:
1. Locate actual heading in the statutory BODY, not merely table of contents.
2. Verify exact official source and legislation identity; retain entire section including paragraphs, definitions, penalties, exclusions and referenced provisions (copy ancillary definition sections separately).
3. Create UTF-8 file beneath legal-sources-20261030/reviewed_sections/JURISDICTION/ACT/SECTION.txt with text reproduced from source (no AI paraphrase).
4. Add an index at reviewed_sections/index.json containing jurisdiction, act, section, source_url, retrieved_utc, compiled_as_at, original_sha256, extracted_text_sha256, source_path, reviewer, full_section_pass, statutory_or_civil, all_definition_links and historical_applicability=NOT_VERIFIED (event dates unknown).
5. If extraction ambiguous, missing, or official page redirects to a shell, report BLOCKED; do not invent an extract. For NSW common-law conspiracy there is no single statutory section: list judicial authority separately, with status NO_SINGLE_STATUTE.

New York's per-section official PDFs contain a single provision; the NSW/CTH sources are whole or partial compilations and require extra section boundary review. Do not claim 'all sections verified' merely because text files exist.

## 3. Stage and send to GitHub using the canonical sender

~~~sh
set -euo pipefail
cd /home/hc3/alchemy-autobuild/repo
OUT=/home/hc3/alchemy-autobuild/legal-sources-20261030
STAGE=/home/hc3/alchemy-autobuild/legal-corpus-package-20261030
mkdir -p "$STAGE/law/sources" "$STAGE/law/tools"
cp -a "$OUT"/. "$STAGE/law/sources/"
cp law/tools/acquire_nswny_statutes.py "$STAGE/law/tools/"
cp law/tools/verify_nswny_statutes.py "$STAGE/law/tools/"
python3 "$STAGE/law/tools/verify_nswny_statutes.py" \
  --manifest "$STAGE/law/sources/source_manifest.json"

cat > "$STAGE/integration.json" <<'JSON'
{
  "schema":"alchemy.autobuild.integration/0.3",
  "package":{"name":"law_nswny_offence_sources","version":"0.1-20261030","kind":"python"},
  "working_directory":".",
  "tests":[{"name":"law-corpus-byte-hashes","argv":["python3","law/tools/verify_nswny_statutes.py","--manifest","law/sources/source_manifest.json"],"timeout_seconds":120}],
  "publish":{"tree":{"source":"law/sources","path":"law/source_corpus/nsw_ny_20261030"}}
}
JSON

python3 tools/alchemy_submit.py --repo . --package "$STAGE" \
  --submitted-by CLAUDE-PC --dry-run --json
~~~

Inspect dry-run and compare manifest/index for every required source and provision. When complete and authorised, execute:

~~~sh
python3 tools/alchemy_submit.py \
  --repo /home/hc3/alchemy-autobuild/repo \
  --package /home/hc3/alchemy-autobuild/legal-corpus-package-20261030 \
  --submitted-by CLAUDE-PC --json
~~~

Follow GIT_SUBMISSION.md. Do NOT hand-upload source files, start Autobuilder, force-merge an inbox branch or claim a submission is accepted on main. Status stays GITHUB_SUBMITTED_PENDING_ACCEPTANCE until approved receiver/authority publishes the law tree and GitHub read-back confirms raw SHA-256. Only authorised reviewers may resolve *verified* push-protection false positives per finding; never disable protection globally, modify raw tags to evade scanning, or leak actual detected secrets.

## 4. Report back

Report exact command/output/return code; retrieval count and section review count per jurisdiction; 1 row per source (URL, bytes, hash, MIME, compilation date, final Git path/commit); each outstanding failure; approved false-positive exemption evidence (if relevant); submission branch/receipt and whether actually accepted to law/ on main. Do not claim offence-rule runtime PASS or legal applicability qualification. Send results to CHATGPT and CLAUDE on reasoned-thought lane.

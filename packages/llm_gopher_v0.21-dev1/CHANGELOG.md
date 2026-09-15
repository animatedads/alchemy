# Changelog

## v0.21-dev1
- Added common bounded PDF/HTML reference reader for local files and HTTP(S) URLs.
- Added approximate printed-page -> physical PDF page lookup; printed/manual page numbers are never assumed identical to PDF indexes.
- Added `reference find` string search with bounded excerpts and ready-to-open physical-page/HTML-section selectors.
- Added deterministic previous/next and +/-N navigation for PDF pages and HTML logical sections.
- PDF text extraction prefers `pdftotext` and falls back to `pypdf`; URL retrieval is byte-bounded and records resolved source/SHA-256.

## v0.20-dev1
- Added article `section`/`topics` projection to `context` and `menu`, including grouped `sections` without changing durable article IDs.
- Advanced built-in Sphere Authoring to v0.3: restored high-value v0.1 authoring craft and added a dedicated Sphere Internals section while retaining v0.19 editor mechanics.
- Added normalized Gemma ooRexx Stabilization sphere v0.2, preserving Codex's Phase 3 experimental facts and explicitly separating historical evidence from any later artifact frontier.
- Added companion sphere-set roll-up metadata for deploying current external spheres through `current/sphere/`.
- Added `sphere edit import-legacy` for pre-`kind` sphere ZIPs/directories; compatible legacy allow-all knowledge policies are mapped to current access-policy shape while the original policy is retained as evidence.
- Legacy `evidence_note` is preserved as opaque `legacy_evidence_note`; it is never parsed into structured provenance (locked by the FISH regression).
- Normalized Access Permissions v0.2, Placement Layers v0.1, Runtime Registry v0.14 and WLU v0.12 for the companion sphere set without changing their semantic version.
- Normalized LLM Access to v0.3, fixing the v0.2 internal-root/profile inconsistency while preserving its dated provider snapshot.

## v0.19-dev1
- Added canonical Sphere Editor: scaffold, object templates, exact object put, bounded corpus-record upsert, structured provenance attachment, changelog entry, validation, lint and package.
- New editor-managed layout standardizes sphere/access policy plus articles, corpora, rules, services and language modules without breaking legacy sphere readers.
- Canonical `provenance[]` separates machine-resolvable artifact/SHA/member/line fields from opaque explanatory `note`.
- Added `sphere-authoring` sphere as the editor's own operations guide.
- Added `PROVENANCE_PANIC / FISH` regression: panicked prose in `note` is harmless when structured provenance is valid.
- Editor mutations return before/after SHA-256 and support stale-source fencing where replacement races matter.

## v0.18-dev1
- Added `workspace-gpt` sphere and bounded workspace operations for filesystem byte/inode inspection, materialisation readiness, ZIP expansion preflight and context recoverability.
- ZIP preflight reads the central directory without extraction, totals uncompressed bytes/member count, checks traversal, encryption and expansion ratio, and compares required bytes/inodes with the destination filesystem plus safety reserve.
- Capacity/recoverability failure returns `HANDOVER_ADVISED` with `PREPARE_HANDOVER`; Gopher does not partially extract and hope the session survives.
- Materialisation checks explicitly distinguish a file being named/attached from its bytes being available in the execution workspace.

## v0.17-dev1
- Added first-class `language-module` pack objects and `gopher language describe/resolve`.
- Composite source examination now resolves examiner/symbol policy from the language module rather than hard-coded extension branches.
- Added Python AST examination as a core examiner.
- Added Java source classification, lexical source examination, exact class/interface/enum/record/method lookup and isolated `javac` compile validation.
- Added conservative grouped Java rules for public-type/filename mismatch and empty catch blocks.
- Added the `java` sphere grounded in delivered Wire UI Swing and FederationBank Java ATM/JMS evidence.
- Java exact symbol lookup gives type declarations precedence over constructors/methods of the same identifier.
- Java editing is deliberately not advertised yet; examination/compile evidence exists before a Java structural editor is claimed.

## v0.16-dev1
- Added sphere retrieval from `current/sphere/*.zip` inside ooRexx API roll-ups using embedded profile identity, not filename guessing.
- Added explicit/local override precedence for improved sphere datasets, with ambiguity rejection rather than silent version guessing.
- Added safe private sphere activation and persistent provenance registry in `state/spheres.json`.
- Active external profiles can reuse installed base packs such as core/oorexx without copying them into the sphere ZIP.

## v0.15-dev1
- Fixed positive operation RC semantics for READY, STAGED and RECORDED terminal states.
- Added explicit transitive `inherits_services_from` sphere service inheritance; destination access control remains authoritative.
- Added `corpus.record.lookup` and `gopher lookup FIELD=VALUE` for exact typed corpus lookup with bounded text fallback.
- Qualified service inheritance against the external Maths sphere with its ooRexx alias services removed.

## v0.14-dev1
- Reworked command help as operational self-documentation derived from the actual CLI feature set.
- Added precise command/subcommand descriptions and workflow-oriented top-level guidance.
- Added shell-native `gopher setup -h/--help`, which performs no setup side effects and documents bootstrap order, environment, safety boundary, options and examples.
- Preserved structured JSON operation output; help remains human/LLM prompt-oriented text.

## v0.13-dev1
- Added internally handled `gopher setup` bootstrap before Python dispatch.
- Setup inventories tools, discovers an ooRexx `.deb`, creates a private mode-0700 environment, unpacks ooRexx without system installation, records a setup manifest, and launches Gopher.
- Setup never downloads missing software.

## v0.12-dev1
- Added dogfood escape recording and operations article.
- Added advisory test-impact discovery after dogfooding exposed the missing capability.
- Qualified development by invoking Gopher context/describe/package-check first and recording the escape before fallback implementation.

## v0.11-dev1
- Added package staging and grouped packaging-rule examination.
- Added automatic exclusion of VCS/cache/generated material and prior root delivery ZIPs during staging.
- Added changelog/test-presence checks and test environment-variable discovery.
- Added task-oriented `gopher package stage` and `gopher package check` commands.
- Preserved v0.10 Gopher/Gopher+ result-cycle semantics.


# Source provenance — Brand Narrative Directive v0.1-dev4

This package is an additive continuation of `brand_narrative_directive_v0.1-dev3.zip`:

- predecessor SHA-256: `5a2ddd59d1127b66b571d37b9a2fa150e5a4dbf7d56eb77673fe99c753807f88`
- public API generation remains `brand.narrative.directive/0.1`

Current adjacent source evidence used for this increment:

- `alchemy_communications_discovery_v0.1-dev14.zip`
  - SHA-256 `fd54d890368a4fe74963454ac907df287e7657f9ecb0a554bb3e74c3aa2c39cd`
  - `QUALIFICATION_DEV14.txt` states inherited ooRexx classes are byte-identical to dev13 and were not rerun there; this package therefore uses dev14 as an exact review-contract/test archive, not as publication authority.
  - `docs/NARRATIVE_EVIDENCE_REVIEW.md` defines NO_DISPATCH evidence review and current terminal-revision/retraction hold semantics.
- `librarian_v2_dev7_20261015.zip`
  - SHA-256 `43694862471938a65223194b070b9b995d5248a24f0e458dd2f926c59689a4e1`
  - `DEV7_NOTES.md` adds declared source lineage while refusing verified provenance, independence, bias, causal or editorial-independence conclusions.
  - inherited dev6 correction/retraction/conflict evidence remains unchanged.
- Sep-27 reviewed Brand line remains the preferred downstream semantic baseline:
  - Structured Utterance v0.3.1
  - Brand Interaction Effect v0.6.1
  - Brand Journey v0.1.1
  - Brand Journey Population v0.3.1
  - Brand Intervention v0.2.1
  - Brand Intervention Effectiveness v0.2.1
  - Brand Intervention Governance v0.2.1

The full local reproducibility package carries the two adjacent archives under `qualification/deps/` as test-only inputs. This Git source-first submission intentionally omits those independently owned archives and exercises their documented adapter surfaces through contract doubles until they are accepted in the repository. No Communications or Librarian source is imported or vendored into `src/`.

Git source layout note:
- The locally reviewed dev4 implementation was one `src/BrandNarrativeDirective.cls` file with SHA-256 `9b5456b7ea5b4418138e760c126e6343519be9d29ecb330e76cc02c631c02917`.
- The Git submission splits that file only at top-level `::class` boundaries into five readable implementation files and retains `BrandNarrativeDirective.cls` as the public loader. No class name, method body, API generation or authority rule is intentionally changed. The r13196 Autobuild gate is authoritative for this source-layout transformation.

# Governed package release

`LlmPaPackageRelease` turns a working source tree into an immutable, verified
release artifact.  It is deliberately not a generic ZIP wrapper and it never
cleans the developer's source tree.

## Objective hygiene versus cognitive release decisions

Objective hygiene is policy-owned and automatic.  Runtime journals, live test
stores, Python `__pycache__`, `*.pyc`/`*.pyo`, compiled object/class output,
editor scratch, logs, crash dumps and regenerated manifests are excluded from
the release snapshot while remaining untouched in the source tree.

Version selection and compatibility are *not* hygiene.  The release service
does not infer that `crypto0.82.zip` supersedes `crypto0.1.zip`, nor that a
`-working` archive is newer or safer than another cut.  Such choices are
explicit cognitive decisions with an authority and reason.

Run analysis without publishing anything:

    pa-tool package release-analyse DIR

Run a release after analysis:

    pa-tool package release DIR decisions.json

A decision file has this shape:

    {
      "schema": "llm.pa.package.release.decisions/0.1",
      "decisions": [
        {
          "scope": "PATH",
          "action": "PRUNE",
          "path": "deps/crypto0.1.zip",
          "reason": "0.82 is the release authority for this cut",
          "authority": "architect"
        },
        {
          "scope": "CONFLICT",
          "action": "QUARANTINE_CONFLICT",
          "conflict_id": "conflict-0003",
          "reason": "two chats produced competing integration cuts",
          "authority": "architect"
        }
      ]
    }

Supported path decisions are `PRUNE` and `KEEP`.  Supported conflict decisions
are `KEEP_BOTH` and `QUARANTINE_CONFLICT`.  A reason is mandatory.

## Shadow detection

Analysis distinguishes harmless repeated test-local identities from production
ambiguity.  Different production files exporting the same public ooRexx class
or routine are a `PRODUCTION_LOGICAL_SHADOW` and block release until resolved.
A `KEEP_BOTH` decision is deliberately rejected for such a shadow because
package/`::requires` ordering could otherwise select the implementation.

Different same-name ZIPs are reported as `COMPETING_ARCHIVE_CUT`.  They may be
kept at distinct paths when both are intentionally required, or quarantined.
Quarantine removes them from the active release tree and preserves every byte
under:

    _release_conflicts/<conflict-id>/<original-path>

No conflicting candidate is silently discarded.

## Release transaction

The release path is:

1. validate approved source root and filesystem node types;
2. inventory source and apply objective hygiene exclusions;
3. apply explicit path decisions;
4. analyse production identities and competing artifacts;
5. refuse unresolved ambiguity;
6. copy active and quarantined material into a new attempt snapshot;
7. generate and verify `MANIFEST.sha256`;
8. qualify mandatory package metadata;
9. publish a content-addressed immutable generation;
10. create the ZIP;
11. verify ZIP structure and exact file-member inventory;
12. hash the artifact and write an immutable release receipt.

The source tree is never pruned or deleted by the release operation.

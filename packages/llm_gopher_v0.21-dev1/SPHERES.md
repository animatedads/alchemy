# Sphere retrieval and override

Delivered spheres in the ooRexx API roll-up live under:

    current/sphere/*.zip

The 2026-09-02 roll-up also carries `current/sphere/Important.txt`, which says:

    Records here may be superceded by your own work
    These are used by our gopher tool

Gopher resolves sphere identity from the embedded `profiles/<sphere>.json`; filenames are not authoritative.

Precedence:

1. explicit `--override FILE`;
2. one matching ZIP in `LLM_GOPHER_SPHERE_OVERRIDE_DIR` (or `$LLM_GOPHER_ENV/overrides/spheres`);
3. matching sphere ZIP under `current/sphere/` in the ooRexx API roll-up.

Local override wins deliberately regardless of version spelling. Multiple local candidates for the same sphere fail as `AMBIGUOUS`; Gopher does not guess which dataset is newer.

Examples:

    gopher sphere resolve maths --api-rollup /path/oorexxapis.zip
    gopher sphere load maths --api-rollup /path/oorexxapis.zip
    gopher sphere load maths --api-rollup /path/oorexxapis.zip --override /work/improved-maths-sphere.zip
    gopher sphere list

Activation extracts only the selected sphere ZIP into the private Gopher environment and records its digest/source/version in `state/spheres.json`. Subsequent `--profile <sphere>` loads that activated sphere profile. Pack references absent from the sphere ZIP (for example `packs/core` or `packs/oorexx`) resolve from the installed Gopher distribution.

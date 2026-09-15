# Sphere Editor

The Sphere Editor standardizes new and maintained Gopher spheres.

Typical cycle:

    # For an old pre-kind sphere:
    gopher sphere edit import-legacy legacy-sphere.zip --out /tmp/canonical-sphere


    gopher --profile sphere-authoring sphere edit create my-sphere --path /tmp/my-sphere --title "My sphere"
    gopher --profile sphere-authoring sphere edit put article --sphere my-sphere --path /tmp/my-sphere --from /tmp/article.json
    gopher --profile sphere-authoring sphere edit evidence article ops.my-article --sphere my-sphere --path /tmp/my-sphere \
        --artifact source.zip --sha256 <64hex> --member README.md --line-start 38 --line-end 45 --claim "..." --note "..."
    gopher --profile sphere-authoring sphere edit validate my-sphere --path /tmp/my-sphere
    gopher --profile sphere-authoring sphere edit lint my-sphere --path /tmp/my-sphere
    gopher --profile sphere-authoring sphere edit package my-sphere --path /tmp/my-sphere --out /tmp/my-sphere.zip

Canonical new layout:

    packs/<sphere>/00-sphere.json
    packs/<sphere>/01-access-policy.json
    packs/<sphere>/articles/<id>.json
    packs/<sphere>/corpora/<id>.json
    packs/<sphere>/rules/<id>.json
    packs/<sphere>/services/<id>.json
    packs/<sphere>/languages/<id>.json
    profiles/<sphere>.json
    tests/
    qualification/
    CHANGELOG.md

Existing sphere layouts remain readable. The editor does not perform destructive layout migration merely to make old content look new.

## Provenance

Canonical provenance is a list of objects containing:

    artifact
    sha256
    member
    line_start (optional)
    line_end   (optional)
    claim      (optional)
    note       (optional, opaque prose)

The `note` field is never parsed to reconstruct authority. This is locked by the `PROVENANCE_PANIC / FISH` regression fixture.

## Legacy import

`gopher sphere edit import-legacy` understands the older manifest/articles/corpus sphere shape used by several early project spheres. It does not mine free-form `evidence_note` strings for artifact/member/line information. Those notes become opaque `legacy_evidence_note`; machine provenance must be attached explicitly later if authoritative structured evidence is available.

Recognized legacy allow-all knowledge-sphere policies are mapped to the current read/exec access-policy representation while the original policy object is retained as `legacy_policy`. Unrecognized restrictive policy shapes fail instead of being guessed.

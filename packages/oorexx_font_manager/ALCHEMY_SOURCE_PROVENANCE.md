# Alchemy source provenance: `oorexx_font_manager`

- Source revision: `oorexx_font_manager_v0.1-dev3`
- Parent delivery: `oorexx_font_manager_v0.1-dev2.zip`
- Parent SHA-256: `52a880246d9db483cde6fb2ceac06e7058ba444421cc1f2fa56dcd3725998b4b`
- Qualification baseline: Open Object Rexx 5.3.0 r13196
- Release archive SHA-256: reported out-of-band because this provenance file is itself a member of the archive.

## dev3 delta

- coverage-aware fallback and renderer-neutral `FontRun` / `FontRunPlan`;
- deterministic ranked and family-collapsed fallback candidates;
- optional coverage-provider seam;
- Fontconfig Unicode-scalar/language coverage lookup;
- explicit missing-glyph evidence;
- live Latin/Japanese/mathematical fallback qualification.

No font binaries are distributed.

## Source-publication normalization

The release archive may carry the Intention Service qualification snapshot. The Alchemy repository publishes that dependency independently under `packages/oorexx_intention_service`; the test runner supports either the vendored standalone layout or the sibling repository package.

# Changelog

## v0.3 — 2026-08-24

- Instantiate Alchemy Wire UI JS v0.4-dev3 `MaterialController`.
- Consume Builder/server `--wui-*` material tokens for FlyLo brand colours, surface and control radius.
- Keep fallback token values only for pre-connection/bootstrap-error rendering.
- Retain the v0.2 browser-safe bootstrap URL flow and zero hard-coded FlyLo business actions.


## v0.2 — 2026-08-24

- Replace duplicated inline session/queue configuration with preferred `bootstrapUrl` handoff.
- Add `bootstrap-config.js` with no-store same-origin fetch semantics.
- Retain explicit inline bootstrap only as a compatibility/test option.
- Add bootstrap tests proving the page need not carry copies of session or queue identifiers.
- Continue to contain no hard-coded FlyLo business actions or booking form.

## v0.1 — 2026-08-24

- Initial Wire UI-owned interactive projection shell.

# Alchemy MCP live/sphere catalogue reconciler — v0.1-dev1

**Architecture:** Tom Dyer. **Implementation and qualification:** ChatGPT GPT-6, 11 Nov 2026.

Offline **build-time** integrity tool, not an ooRexx runtime provider. It supplies the
fail-closed preflight missing from the accepted MCP composite catalogue workflow.
The authoritative runtime remains `McpProjectWireService`, its single-writer journal,
HTTPS principal context, and the independently injected Gopher resolver.

## Defect addressed

At 17:38 UTC, 11 Nov 2026 the authenticated Rasen Falcon project catalogue returned
137 runtime entries and **zero sphere** entries. The source MCP v0.2-dev8
`catalog/components.json` is **historical**: 82 runtime artifact entries + 53 sphere
entries (129 unique IDs). Installing that composite wholesale would silently drop
new runtime components. Separately, direct Rasen Falcon `sphere.check` resolved
Gopher packs, but `sphere:rasenfalcon` could not be used as a project component.

## Build candidate

Supply three independently captured files:

- `live.json`: unmodified authenticated `project.components.list` snapshot,
  with its complete `components` array, including aliases and a verified entry count.
- `runtime.json`: **current, operator-accepted** runtime-only catalog with
  `sourceArtifact` and lower-case 64-digit `sourceSha256` of the accepted source.
  Do not use the historical 82-row MCP dev8 fixture if 137 are live.
- `spheres.json`: validated and approved first-class sphere catalog from the
  actual sphere-rollup, with source artifact and digest and a per-sphere archive hash.

```sh
python3 reconcile_catalog.py \
  --live-export live.json --runtime-source runtime.json --spheres spheres.json \
  --expected-live-runtime-entries 137 \
  --output candidate-components.json --report candidate-report.json
```

Checks: complete live count; every canonical runtime ID preserved exactly;
no runtime alias removed; no volatile ownership/receipt state copied into the
source catalog; sphere canonical ID = `sphere:<sphereId>`; valid source/archive
SHA-256; no duplicate sphere ownership identities. Historical multiple runtime
artifact rows for the same runtime component ID remain valid.

It **refuses** any missing or additional runtime IDs, including an old 82-row
snapshot, unless a future separately approved source reconciliation is completed.
It writes nothing on a rejected candidate and will not overwrite existing output.

Output carries `CANDIDATE_UNINSTALLED` and exact digests of the *input files*,
which are not substitutes for the declared source-rollup SHA-256. It cannot prove
that an operator's source digest corresponds to an externally signed/approved
archive: inspect/attest that source separately. No journal read/write, network,
server reload, authentication or deployment code exists in the tool.

## Operator acceptance (not performed here)

Before activating the candidate: prove current package/rollup provenance and
preserve full runtime catalogue, backup existing journal and catalog, verify
single-writer mode, inject a *qualified* `McpGopherSphereChecker` rather than
`McpProjectNullSphereChecker`, run ooRexx r13196 MCP regression, then test
`componentKind=sphere`, `sphere:rasenfalcon`, alias collision, ownership deny,
component/sphere mismatch, source hash, restart and rollback. The standalone
Gopher resolver being able to read `rasenfalcon` is not this MCP test.

Track issue: https://github.com/animatedads/alchemy/issues/143.
Rasen Falcon lanes: `agent-mailbox` REQ-00003485; `llm_gopher` REQ-00003483;
`rasenfalcon-operator-console` REQ-00003487.

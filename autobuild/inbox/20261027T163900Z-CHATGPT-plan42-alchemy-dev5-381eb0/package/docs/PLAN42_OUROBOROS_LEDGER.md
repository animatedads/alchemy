# Plan42 Ouroboros Ledger

`tools/ouroboros_ledger.json` is the machine-readable evidence ledger for Plan42
roundtrip cycles.

Rules for adding records:

1. Add one record per proven cycle only.
2. Put aspirational or pending work under `pending_surfaces`, not under `records`.
3. Record the exact surface, cycle, validator, evidence paths, proof level, and limitations.
4. Distinguish exact canonical recovery from semantic preservation.
5. Do not mark live acceptance unless the runtime/compiler command actually ran.

Current proof levels used:

- `semantic_preservation`: the roundtrip preserves named routines/classes/constants
  and other semantic ratchets, but the regenerated Plan42 may contain additional
  fallback `impl` nodes.
- `exact_embedded_marker`: generated source contains the canonical Plan42 marker
  and extraction recovers the original JSON exactly.
- `exact_embedded_marker_static`: same as exact marker recovery, but without a
  live target runtime/compiler proof on this host.

Current limitations:

- C and Rust marker recovery uses the embedded Plan42 block. It is not a general
  C or Rust parser.
- Rust is now a Python-side `plan42c.py` scaffold backend for a conservative typed
  subset. It is not live accepted until `rustc` proof is recorded.
- ooRexx remains static-pass until a host with an ooRexx runtime records a live
  class/method smoke.

## Patch membrane evidence

For AI-assisted edits, prefer the guarded `tools/fop.py` workflow when a narrow
line-range or zip-entry repair is enough:

1. inspect with `fop show`, `fop locate`, `fop locate-method`, or `fop zipls`;
2. dry-run with `--check --unified-diff`;
3. guard with `--expect-hash`, `--expect-lines`, `--expect-method`, or
   `--expect-entry-hash`;
4. mutate only with `--backup`, `--backup-manifest`, and `--log`;
5. validate with the relevant compiler/static/runtime tests before recording a
   ledger cycle.

This is not a substitute for tests. It is the edit membrane that makes the patch
operation itself auditable and recoverable.

# Librarian source lineage — v0.11

The source lineage is intentionally split into three artefacts.

## 1. Recovered original

`librarian/source/librarian_wordnet_oorexx.rex.original`

SHA-256 is pinned by `tests/test_librarian_salvage_delta.py`:

```text
cfaf24c475f99008388f58cd2b43ba900deaad24af286a6e264fb2684045ac5e
```

This file is retained untouched.

## 2. Mechanical salvage checkpoint

`librarian/LibrarianSalvagedCore_v09.cls`

This is mechanically regenerated from the recovered original by:

1. removing the executable bootstrap lines 1..12;
2. replacing exactly 11 keyed `~allItems(` accesses with native keyed `~allAt(`;
3. renaming exactly two unsafe ordinary `result` locals and their directly associated references.

The salvage test recreates the file byte-for-byte. This checkpoint represents what was *recovered* rather than what was later hardened.

## 3. Reviewed hardened core

`librarian/LibrarianCore.cls`

This is intentionally **not** claimed to be a mechanical salvage. v0.11 changes it to repair determinism/evidence defects found by adversarial review, including:

- Soundex/EditDistance execution repair;
- deterministic Soundex tie order;
- model object freeze/get-only component references;
- immutable model leaf records;
- backing-collection exposure reduction;
- POS-respecting target lookup;
- explicit conflicting duplicate target validation;
- scoring-contribution versus multi-path provenance separation;
- candidate evidence retention;
- selected-sense evidence retention;
- cache v2 canonical serialization;
- surface/canonical resolution distinction.

`tests/test_librarian_hardened_core_audit.py` verifies characteristic hardening markers and rejects known legacy constructs. The behavioural regression suite, rather than an enormous fragile text-rewrite script, is the primary proof of these intentional changes.

## Rule

Future work must not collapse these three artefacts back into one ambiguous file. If a new hardening changes `LibrarianCore.cls`, the untouched original and mechanical salvage checkpoint remain unchanged unless new archaeological evidence proves that the recovered original itself was incorrectly captured.

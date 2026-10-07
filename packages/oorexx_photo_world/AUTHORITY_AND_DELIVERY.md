# Authority and delivery contract — dev17

Photo Survey World follows the portfolio review distinction between **source/development authority** and **sealed-delivery snapshots**.

The archives under `deps/` are reproducibility material. They do not become the development authority for Maths, Physics, Alchemy Objects or Alchemy Foreign Object merely because they are copied into this ZIP. Development resolves the named authoritative package/version and checks it against `compatibility-lock.json`.

Python Macrospace v0.31.6 is now present as an exact sealed-delivery snapshot and qualified in this build. Its bundled presence does not make Photo World the source authority; a stale or alternate bridge must not silently satisfy the compatibility lock through `REXX_PATH` or filename coincidence.

## Numerical authority

Photo Survey World owns survey semantics. ooRexx Maths owns reusable mathematics, numerical containers, precision contexts and numerical provider policy. A Python package may execute a specialised model or mesh operation, but it does not become the numerical or survey authority simply because it is written in Python.

## Derived evidence and promotion

Foreign/model output enters as raw derived evidence (`*_RAW`). `SurveyEvidencePromotion` records the explicit conversion of supported raw depth or mesh evidence into a Maths-backed `SurveyDepthEvidence` or `SurveyMeshEvidence` object. The record checks source digest, provider and provider-version continuity. It reports `PROMOTION_RECORD_ONLY` and has no method that mutates `SurveyWorld`.

Promotion is therefore auditable lineage, not automatic truth. A separate Photo Survey World domain operation remains responsible for deciding whether evidence becomes part of a solved world hypothesis.

## Qualification evidence

`qualification/qualification-index.json` and `qualification/receipts/*.json` distinguish executed tests from tests that were not run. Historical prose records remain historical evidence only. No receipt is allowed to turn `NOT_RUN` into inherited `PASS` merely because a predecessor version passed.

## dev17 Macrospace snapshot

The exact Macrospace v0.31.6 archive (SHA-256 `38175f11db8e7e7de28a37e4012c92a94109b4fbcfec7fb96ee166b4d4644c6b`) is now bundled only as a sealed-delivery snapshot. Bundling does not transfer source authority to Photo World. The live-object crossing is qualified against the authoritative Alchemy Objects v0.8.2 semantic-target tree and the r13196 runtime.

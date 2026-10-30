# ooRexx D-Bus connector — Gopher sphere v0.2

**Core architectural invariant:** modernise the existing native `dbusoorexx` ooRexx connector; never reinvent the native D-Bus implementation or require BSF4ooRexx. The native package MUST remain installable, testable and usable without Alchemy, ConnectSelector, RPC, Queue Fabric, LDAP or Instrumentation Mesh. All integration adapters are optional external packages.

## Start here

- `ref.oo-rexx-dbus.architecture` — native-first package independence
- `ref.oo-rexx-dbus.source-authority` — 2015 historical vs reported 2026 SVN candidate
- `ops.oo-rexx-dbus.qualification` — real native qualification gates
- `ops.oo-rexx-dbus.archive-audit` — bounded ZIP preflight
- `ops.oo-rexx-dbus.api-diff` — NEW: ooRexx static public API inventory/comparison
- `ops.oo-rexx-dbus.upstream-diff` — NEW: archive-content comparison

## Working source and tests

Package: `packages/oorexx-dbus-qualification`.

Run from package root:

```sh
python3 -m unittest discover -s tests -v
python3 tools/audit_archive.py historical.zip
python3 tools/audit_archive.py candidate.zip
python3 tools/compare_upstream.py historical.zip candidate.zip --out diff.json
python3 tools/api_inventory.py /path/to/candidate/extracted --compare-to /path/to/historical/extracted --strict
```

Extraction of untrusted archives is deliberately **not** part of the analysis tools. Only unpack audited source into isolated scratch directories with manual review. API signature inventory is a static heuristic, not a full ooRexx parser and not evidence of C++ or runtime compatibility.

## Evidence ledger — 2026-10-29

- 14 ZIP auditor regression tests: PASS locally (previous increment; rerun in current 29-test local suite).
- 11 new API inventory tests: PASS locally on synthetic fixtures.
- 4 new upstream content-diff tests: PASS locally on synthetic fixtures.
- **29/29 total tests: PASS locally.**
- A disposable host session-bus ListNames roundtrip: PASS (not the native ooRexx connector).
- Historical 2015 and newer 2026 `dbusoorexx` binaries/sources: not available for exact package diff in this workspace.
- Original C++ build: NOT_RUN.
- Original ooRexx interpreter binding: NOT_RUN.
- Gopher runtime load/qualification: NOT_RUN.
- Autobuilder: NOT_RUNNING; no autobuilder receipt claimed.
- Rasen Falcon lane: `oorexx-dbus`; coordination REQ-00001903 to CLAUDE.

### Scope boundary against deployment critical path

This D-Bus work has no demonstrated dependency needed to start the Rasen Falcon website, own HTTPS/LDAP, SMTP/IMAP mail or MU↔MI XTP transport. Do not make those services wait on D-Bus or claim to have deployed them through this component. D-Bus might be an optional Linux service integration later.

## Attribution

Architecture: project owner. Qualification tooling and sphere update: ChatGPT (GPT-6). No native package code authored or altered.

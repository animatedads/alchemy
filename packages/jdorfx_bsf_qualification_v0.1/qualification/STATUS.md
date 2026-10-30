# Qualification status — 2026-10-29

| Gate | Status |
|---|---|
| Shell syntax + four fail-closed cases | PASS_LOCAL (mock-only / preflight) |
| Mock runner three successful and six deliberately failing paths, plus retained evidence | PASS_LOCAL (mock-only; not bridge acceptance) |\n| Patched native stale activation forced-GC | NOT_RUN on this host (no ooRexx installed) |
| BSF850 Java object / Java callback | NOT_RUN on this host (no selected bridge/interpreter) |
| JDORFX 2D/3D/animation/window samples | NOT_RUN (new JDORFX archive absent) |
| Upstream native-argument patch | UNCONFIRMED MERGE after r13284 |
| New JDORFX source archive SHA-256 | UNKNOWN |
| Visual parity and production admission | BLOCKED |

The historical 2026-10-23 r13284 *upstream* status and local patch results are described in `animatedads/oorexx/oorexx2cpp/ootest/interpreter_bugs/BUG_REPORTS.md`. This package does not claim new live runtime evidence.

Latest code changes: opt-in evidence directory and dependency hashes; Java wrapper-aware JVM discovery; required known output marker and contained JDORFX source path; exact-line BSF completion marker; required JavaFX graphics and controls modules; sample-directory execution.

Rasen Falcon testing request REQ-00000655 received response REQ-00000841: no runtime commands performed, exact workstation paths/approval outstanding. Follow-up REQ-00000845 similarly reports no tests. See `qualification/UPSTREAM_TRACKER.md` for distinct upstream native API conditions. Autobuilder not used.

These mock controls intentionally substitute fake rexx, native compiler and BSF input files to exercise harness failure behaviour; they must never be presented as interpreter or JDORFX evidence.

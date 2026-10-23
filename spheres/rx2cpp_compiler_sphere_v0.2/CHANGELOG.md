# Changelog

## 0.2 (2026-10-23)
- Rebased on rx2cpp commit 43b440e (archive sha256 10af342e...7d3035); 27 provenance entries, ranges recomputed.
- interpreter-bugs: bug 2 ticket ready (TICKET_bug2.md), patch verified on a trunk a4210fc build; procedure now
  includes building trunk and testing unpatched and patched.
- security-managers: two more cases checked identical (same-activation protected send; protected MAKESTRING / =
  reached by language operations).
- continuity: Plan42 downstream pin record.

## 0.1 (2026-10-23)
- First rx2cpp sphere (Claude (Opus 5.5); architecture Tom Dyer).
- Grounded in rx2cpp commit c5c7b22: standing rules, build and qualification procedure, native lane,
  interpreter epoch, environment-symbol cache, security managers, performance, known differences,
  interpreter bugs and upstream status, people.
- Corpus rx2cpp.lessons: approaches that failed and why.

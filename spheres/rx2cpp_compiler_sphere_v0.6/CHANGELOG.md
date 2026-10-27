# Changelog

## 0.6 (2026-10-27)
- Rebased on rx2cpp main 462b445 (archive sha256 019f665b...7b2934): d43c058, the merge of wip-2026-10-13 at
  59d2019 (138 scripts, fixed point native 179 s / interpreted 275 s, merge gate 38.0 s against 117.5 s), then the
  handoff records for that code; 39 provenance entries.
- performance: the cycle-collector leak (617,823 states, about 2.1 GB, to bounded, 315 MB) and the callgrind-led
  call-path work (80.1 G to 65.6 G instructions a pass); rexxcps still slower compiled (Value copies); callgrind
  for flat profiles.
- lessons: exceptions in hot paths; cycles through the interpreter; statistics free when off; flat profiles;
  memory of parallel builds.
- continuity: baseline, fixed point, regression (138 scripts, two-hour jobs), environment cache per name.
- qualification: results at 59d2019 / d43c058; resumable regression across two-hour jobs.

## 0.5 (2026-10-26)
- qualification: fifth gate, pbench2 on the exact merged commit; gates qualify the commit they ran on.
  Reason: e3d8d00 was merged on a benchmark of 61285d6, and fa1179f's 55 s -> 103 s regression had passed the
  regression and the fixed point (found by checking this session's reasoning with Reasoned Thought FactsMatrix).
- performance: main e3d8d00 measured, 54.1 s against 144.8 s interpreted (2.68x), 79,398 trips a pass;
  trips are about 1% on pbench2, so "crossings dominate" is now "can dominate: count and sample first".
- lessons: benchmark the merged commit.
- start: main is updated only after the merged commit is benchmarked too.
- Provenance unchanged (32 entries against rx2cpp-e3d8d00.zip); the benchmark rows are in rx2cpp commit 7f40a61.

## 0.4 (2026-10-25)
- Rebased on rx2cpp main e3d8d00 (archive sha256 1f97f043...47e16e), merged after the full regression (137
  scripts at cd77a49) and the fixed point (native 250 s, interpreted 344 s) passed; 32 provenance entries.
- environment-symbols: kept per name (.environment's own LOCAL method entry had disabled the cache), QuietEpoch.
- performance: Rexx Parser 2.46x (55.0 s against 135.3 s), trip cost and counting.
- lessons: the never-kept cache; strings compared with .nil.
- qualification and continuity: workstation tests through the project mailbox (component rx2cpp).

## 0.3 (2026-10-24)
- Rebased on rx2cpp main fa1179f (archive sha256 7c660568...b62089), merged after the full regression (137
  scripts, SKIP bsf / python / kernel objects) and the self-build fixed point (native 226 s, interpreted 317 s) passed.
- environment-symbols: fixed class tables taken once at library load (StringTableAt, no allocation per lookup).
- lessons: allocation where the interpreter allocates none changes collection timing (test_object_lifetime.sh).
- qualification: fetch main explicitly before pushing; merge commit keeps tested hashes.

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

# Photo Survey World v0.1-dev18 qualification

Qualification runtime: **Open Object Rexx 5.3.0 r13196 Internal Test Version**, 64-bit, build 3 Aug 2026. Runtime package SHA-256 remains `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`.

## Indoor room solver

`tests/test_indoor_room_solver.rex` passed under the real interpreter.  It represents the supplied 3.750 m opposite-wall measurement, 5.000 m approximate long-wall prior and 2.750 m opening anchor as explicit evidence and solves the WIDTH/LENGTH envelope through the Maths matrix solver.  Current result: **3.75 m x 5.00 m, 18.75 m2**, opening anchor **2.750 m**, remaining reference span **1.000 m** under the first Manhattan hypothesis.

## Photographic structure provider

Python Macrospace v0.31.6 was used as the actual Python object/class crossing.  `PhotoWorldStructureProvider` (OpenCV 4.13.0 LSD) processed all six supplied room photographs and returned only `STRUCTURE_RAW` evidence.  The six observed accepted long-segment totals were 27, 40, 20, 26, 33 and 9 respectively.  No provider result was promoted into `SurveyWorld` geometry.

## Regression

All thirteen ordinary Photo World regression programs passed, including the new indoor solver.  The existing Macrospace provider/live-Maths crossing also remained green.  The standards-enforcer result for the final archive is recorded separately in the release receipt/log.

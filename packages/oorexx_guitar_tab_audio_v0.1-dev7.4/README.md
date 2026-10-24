# ooRexx Guitar Tab / MIDI Audio v0.1-dev7.4

A physically modelled guitar/bass/drum band frontend for ooRexx. ASCII tab and Standard MIDI File input are performance/control frontends; they do not supply audio samples.

## Implemented integration

- Type 0/1 Standard MIDI File parsing with PPQ tempo maps, running status, note pairing, programs, controllers and pitch bend preservation.
- Six-string guitar voicing and four-string E1/A1/D2/G2 bass voicing.
- MIDI channel 10 -> stateful Physics drum kit mapping.
- Guitar/bass/drum peer render objects and ooRexx Message/activity concurrency.
- Physical pressure/sample output through the existing Physics/Audio boundaries; sampled drum IR substitution is not part of the delivered renderer.

Historical r13196 qualification evidence is retained in the `VALIDATION*.txt` files. The three-second Master of Puppets qualification window rendered 22 guitar notes, 46 bass notes and 28 physical drum events with the three stem calculations overlapping.

## dev7.4 standards review

The band frontend was reviewed with the portfolio standards enforcer. Guard-dependent boolean expressions were rewritten as explicit control flow. The GitHub publication pass also removed every `+0` site: numeric inputs are checked explicitly with `datatype(...,'N')` or `datatype(...,'W')` at the owning boundary and the original validated value is retained. `+` is method dispatch, not numeric coercion.

The review also extended the guard rule beyond the checker’s original `&` detection: `&`, `|`, and `&&` are only used where every operand is safe to evaluate. The concrete `q==.nil | q~items=0` MIDI reader trap was replaced by nested guards.

Final publication-source enforcer result: **0 ERROR / 48 WARN / PASS**. All 48 warnings are the `LOOP_INVARIANT` heuristic and remain manual review prompts.

## GitHub publication reconciliation — 2026-10-24

Current repository peers observed at publication are Physics World `0.1-dev50`, Maths `0.16`, and Rexx-tronics `0.1-dev25`. The dev7.4 runtime results were obtained against the dependency versions named in their historical validation files and are **not** silently promoted to dev50/v0.16 requalification.

Generated WAVs and generated gauge CSVs are not source authority and are omitted from Git. User-supplied copyrighted MIDI fixtures used for qualification are also not redistributed.

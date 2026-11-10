# SLAM 450 v0.89: Claude Haiku 5.5 in the pilot's seat (summary for Gemini and ChatGPT)

- **Architecture:** Tom Dyer
- **Coding:** ChatGPT GPT-6 (SLAM 450 v0.6–v0.86 base); Claude (Opus 5.5) (v0.87–v0.89, Physics World dev51, Maths v0.20, Anthropic provider v0.3, compress v0.1-dev3)
- **Pilots H1/H2:** Claude Haiku 5.5 (`claude-haiku-5-5`); their own notes are in `*_llm_calls.csv`
- **Written by:** Claude (Opus 5.5), 3 November 2026
- **Picture:** `slam450_v089_squad_plan.png` (plan view of all five aircraft in all three races, one common scale)

## 1. Setup

**Line-up:**

| Team | Aircraft |
|---|---|
| RED | A1 SLAM quad (solo, no radio) + H1 Haiku quad |
| BLUE | A2 SLAM quad + A3 SLAM fixed-wing (buddy radio) + H2 Haiku quad (reads the Blue radio summary) |

**World:** synthetic Sydney Harbour (PowerSLAM v0.40, 125 solids), seed 45046, 5 red targets. A target is claimed by the first aircraft whose swept path comes within 2.5 m of it. There are 3 wind bands and a 180-tick cap (1 tick = 1 s).

**Physics:**

- Physics World dev51: the quad uses momentum theory (hover = 1.00 energy unit/tick = 143 W); the wing uses a point mass with a parabolic polar (L/D 10, stall 6.6 m/s, natural glide).
- Packs: 900 units per quad; 612.8 units (24.4 Wh) for the wing.

**What Haiku receives each tick** (the same as any SLAM pilot, nothing more):

- its own 360×180 onboard panorama as a 960×242 PNG;
- its own battery and airflow readings;
- public claims;
- the shared flight-window hints (QUAD SPEED 0 TO 7 / HOVER TRUE, FIXED SPEED 7 TO 11 / HOVER FALSE, …);
- its own last 8 notes.

It gets no positions, target coordinates or wind truth. It answers with one JSON command: target, yaw, forward, climb, side, lookup, note. Thinking was off, so replies are immediate. The race is turn-based (the simulation waits for the reply), and both Haiku calls run in parallel.

**Modes:**

- **EYES:** image plus instruments only.
- **ASSIST:** also receives the onboard vision routine's bearing, elevation and size for each target, as numbers.

**Squad rule:** a collision knocks only that aircraft out; the race continues.

## 2. Results (all independent auditors PASS: energy ledger replay, tracks/scene/separation, claim reach, aircraft type)

| Race | Result | Red | Blue | Haiku closest pass | Haiku cost |
|---|---|---|---|---|---:|
| 1. EYES (SLAM crowd-vision bug) | step limit, 2/5 | 0 | 2 (wing 2) | 15.5 m | $0.054 |
| 2. EYES, bug fixed | **COMPLETE at 133** | 0 | **5** (wing 3, A2 2) | 37 m | $0.040 |
| 3. ASSIST, bug fixed | **COMPLETE at 132** | 1 (A1) | **4** (A2 2, wing 2) | **5.3 m** | $0.043 |

- **Total:** 902 Haiku decisions for $0.139, at about 230–590 ms mean latency per call.
- **Reliability:** after the first test, 0 transport failures and 0 unparseable replies. Neither Haiku aircraft crashed or ran flat.

## 3. Findings

1. **Haiku is safe but doesn't hunt.** It averaged 1.9–2.9 m/s, used small yaw corrections, never bought a camera view, and kept well clear of other aircraft. It never claimed a target.
2. **Part of the gap is perception.** From the picture alone it misread the dark red shades and estimated positions loosely. With exact bearings (ASSIST), its closest pass fell from 37 m to 5.3 m.
3. **The rest is control.** With correct numbers it still steered wrong. One note reads "T4 bearing 102, el 59, above horizon: descending", which is the wrong way. Another has it creeping at 1 m/s with the target dead ahead because a rival seemed "~4 m" away. It reasons about flight in words; it doesn't reliably turn that reasoning into control.
4. **SLAM's fixed-wing was the strongest pilot:** 7 of 12 claims across the three races, on 21–27% of a SLAM quad's flight energy.
5. **My harness bug (race 1), fixed.** With several aircraft sharing a silhouette symbol, SLAM's vision merged them into one box, so its separation rule saw a permanent threat and A1 dodged sideways on 126 of 180 ticks.
   - **Fix:** connected-component blobs (`Slam450Vision~observeBlobs`).
   - **Trio unchanged:** the v0.88 three-aircraft races replay byte-identical.
   - **Side effect:** type observation now works in crowds: 1,280 sightings, 0 misread.
6. **Briefing correction between races 1 and 2:** I added one factual line, "low targets require descending; descending is free and safe above 5 m". In race 1 Haiku had read "never go near the water" as "never descend".

## 4. Against the predictions

- **ChatGPT predicted** that SLAM wins at flying and the LLM may win at deciding where to fly, with a hybrid as the likely favourite. The flying half is borne out. The deciding half wasn't tested, because Haiku flew directly.
- **I predicted** that the LLM loses at the stick and might earn its place as commander. Same result, same untested half.

## 5. Next experiments (cheap: a whole race costs cents)

- **Hybrid seat:** Haiku chooses the target, camera lookups and energy trade-offs every 16 ticks; SLAM flies.
- **Adaptive thinking** (implemented, not yet raced).
- **Several seeds** for statistics.
- **Continuous-time mode:** the aircraft keeps moving while the model thinks.

## 6. Artefacts

- **SLAM 450 v0.89 package:** races, logs, Haiku notes, audits.
- **New estate packages:** Anthropic provider v0.3 (images, cached briefing, thinking control, Haiku 5.5) and compress v0.1-dev3 (indexed PNG writer, pure Rexx plus an optional foreign-runtime lane).
- **Earlier submission:** Physics World dev51 and Maths v0.20 (Autobuild inbox).

Claude (Opus 5.5)

# SLAM 450 v0.90 — summary for Gemini and ChatGPT

Architecture: Tom Dyer · Coding: ChatGPT/Claude · Written by: Claude (Opus 5.5), 2026-11-03

**Setup.** This is a 5-aircraft race over a synthetic Sydney Harbour (PowerSLAM v0.40 cuboid scene) to claim 5 red targets.
- **Teams:** RED = SLAM quad + Haiku quad; BLUE = SLAM quad + SLAM fixed-wing + Haiku quad. Haiku is Claude Haiku 5.5.
- **Pilots' inputs:** every pilot sees only a 960×242 panorama plus its own instruments. No pilot is ever given positions.

**Questions tested today (2 seeds each, every race independently audited):**
1. **Haiku in the seat** (it flies): 9 races, **0 claims**. It creeps and waits.
2. **Haiku in the back seat** (SLAM flies, Haiku picks targets and speed): its craft claimed targets in **all 6 races**.
   The team score moved both ways. The advice was almost entirely target choice: "FAST" on 490 of 494 calls.
3. **Moving targets.** Targets fly at 3 m/s on committed legs. They are drifted by wind and correct course every tick,
   route around buildings, and never dodge aircraft.
   - The proof that they ignore aircraft: each target's track is bit-identical between control and treatment runs until it is claimed.
   - **Finding:** SLAM's quads end up in stern chases about 11 m behind a target and never close.
     Their approach braking was tuned for static targets: the "not growing" floor is 3.0 m/s, which equals the target speed.
4. **Static plan map for Haiku.** The map is north-up, unlabelled, has no "you are here", and is the same for every seed.
   It made no difference: 4 Haiku-craft claims with it, 4 without. The race box is open water with a single building in it, so the map had little to offer.

**Cost:** $0.42 of API for all 17 evidence races.

**Pictures:**
- `evidence/v090_plan_view/slam450_v090_moving_plan.png`: four panels (control, back seat, back seat + map, in seat + map), with target tracks dotted.
- `evidence/v090_plan_view/slam450_v090_llm_map.png`: the exact map Haiku sees.

**Next (v0.91):** an obstructed, larger course, so that the map, the target route-around and SLAM's obstacle handling all matter.

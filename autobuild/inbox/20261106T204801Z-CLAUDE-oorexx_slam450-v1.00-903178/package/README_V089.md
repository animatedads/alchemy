# SLAM 450 v0.89: two Claude Haiku 5.5 pilots join the race

- **Architecture:** Tom Dyer
- **Coding:** ChatGPT GPT-6 (v0.6–v0.86 base); Claude (Opus 5.5) (v0.87–v0.89, plus the estate additions below)
- **Update written by:** Claude (Opus 5.5), 3 November 2026
- **Pilots:** Claude Haiku 5.5 (`claude-haiku-5-5`) as H1 and H2, each signing its own notes in `*_llm_calls.csv`

## Line-up (5 aircraft)

| Team | Aircraft |
|---|---|
| RED | A1 SLAM quad (solo, no radio) + **H1 = A4, Haiku quad** |
| BLUE | A2 SLAM quad + A3 SLAM fixed-wing (buddy radio) + **H2 = A5, Haiku quad** (reads the Blue radio summary) |

## What the LLM sees (same as a SLAM pilot)

**Inputs:**

- its own onboard 360×180 panorama, as a 960×242 PNG;
- its own battery meter and airflow instruments (level band, pitot);
- public claims;
- the shared flight-window hints;
- its own 8 most recent notes;
- a fixed-camera view, if it paid 3 units for one;
- for H2 only, the Blue radio summary.

**Not given:** XYZ, target coordinates, wind truth, or any referee state.

**Modes:**

- **EYES:** image plus instruments only.
- **ASSIST:** also receives the onboard vision routine's bearing, elevation and size for each target.

The simulation pauses while the pilots think (turn-based). Both calls run in parallel each tick. Thinking is off, so each reply is immediate.

**Squad rule:** an aircraft that collides is OUT, and the race continues. In the trio, one collision ended the race for everyone.

## Results (seed 45046, 180-tick cap, all auditors PASS)

| Race | Result | Red | Blue | Haiku closest approach | Haiku cost |
|---|---|---|---|---|---:|
| 1. EYES (crowd-vision bug, see below) | step limit, 2/5 | 0 | 2 (wing 2) | 15.5 m | $0.054 |
| 2. EYES, SLAM bug fixed | **COMPLETE at 133** | 0 | **5** (wing 3, A2 2) | 37 m | $0.040 |
| 3. ASSIST, SLAM bug fixed | **COMPLETE at 132** | 1 (A1) | **4** (A2 2, wing 2) | **5.3 m** (H1) | $0.043 |

Total spend, including the smoke test: **$0.139** for 902 Haiku decisions. No call failed after the first fix, 2 replies out of 12 in the smoke test didn't parse, and no Haiku aircraft crashed.

## What we learned

1. **Haiku flies safely but doesn't hunt.** It never crashed and kept its distance from other aircraft. But it averaged 1.9–2.9 m/s with small turns, and never bought a camera view, although the briefing says 7 m/s is the cheapest speed.
2. **Perception is part of the gap.** In EYES mode it read the picture loosely. It confused dark red shades and estimated pixel positions roughly. Given exact bearings (ASSIST), its best approach improved from 37 m to 5.3 m.
3. **Control is the rest.** With correct numbers in hand it still flew wrong: "T4 bearing 102, el 59, above horizon: descending" goes the wrong way, and it crept at 1 m/s with the target dead ahead because a rival was "~4 m" away. It reasons about flight in words. It doesn't reliably turn that into stick inputs.
4. **A bug in my harness, now fixed.** Race 1 crippled SLAM's quads. With several aircraft sharing a symbol, SLAM's vision merged them into one wide box, and the separation rule saw a permanent threat: A1 dodged sideways on 126 of 180 ticks.
   - **Fix:** `Slam450Vision~observeBlobs` (connected components) is now used for separation, the wing's threat check and type classification.
   - **Trio unchanged:** both v0.88 trio races are **byte-identical** after the fix.
   - **Side effect:** type observation now works in crowds: 1,280 sightings, 0 misread.
5. **Briefing correction between races 1 and 2:** I added one line saying that low targets require descending, and that descending is free and safe above 5 m. In race 1, Haiku read "never go near the water" as "never descend". This is a factual clarification, not coaching on technique.

## Estate packages (missing pieces added where they belong)

- **`oorexx_ai_provider_anthropic` v0.3**
  - `AnthropicMessages.cls`: multi-block messages (text and PNG images), cached system prompt, and thinking control (`thinkingOff`, `thinkingAdaptive(effort)`).
  - Full usage reporting: input, output, cache read and write, latency, and rate-card cost.
  - Haiku 5.5 added to the catalogue at $0.10/$0.50 per Mtok, with batch eligibility left off because it's unverified.
  - The selector now picks Haiku 5.5 as the cheapest model; its test follows the rule instead of hard-coding a model.
  - Credentials keep the v0.2 discipline: SecretBroker lease, a mode-600 curl config, and never on argv.
- **`oorexx_compress` v0.1-dev3**
  - `NativeAdler32`, `Rfc1950Framing` and `IndexedPngEncoder` (pure Rexx, bootstrap-clean).
  - Optional accelerated `foreign/ForeignPngProvider.cls` (Python zlib through the Foreign Runtime).
  - Both lanes decode to identical pixels, checked independently.
- **Physics World dev51 and Maths v0.20:** used unchanged from the earlier submission.

## SLAM v0.89 code

- `Slam450Squad.cls`: squad referee for N aircraft in teams, with knock-outs.
- `Slam450LlmPilot.cls`: the LLM seat, with LIVE and STANDIN modes and EYES/ASSIST options.
- `bin/race450_squad.rex`: derived from the trio runner, so SLAM pilot logic is unchanged.
- `Slam450Vision~observeBlobs`: one observation per separately drawn aircraft.
- Auditors:
  - `audit_squad450.py` (new): tracks, scene solids, knock-out consistency, claim reach.
  - `audit_battery450.py` and `audit_aircraft_type450.py`: generalised to N aircraft.
- Native suites: 2,958 checks across 18 suites, all passing.

## Run

Stand-in pilots need no key; LIVE needs `ANTHROPIC_API_KEY`. Arguments 8–11 are the LLM mode (`STANDIN`|`LIVE`), the eyes mode (`EYES`|`ASSIST`), the projection lane, and the thinking setting (`OFF`|`LOW`|`MEDIUM`|`HIGH`).

```
export ALCHEMY_ROOT=/path/to/alchemy
```

```
. bin/slam450_env.sh
```

```
mkdir -p /tmp/squad
```

```
rexx bin/race450_squad.rex /tmp/squad/race 45046 LEGACY 180 WIND BATTERY AUTO LIVE ASSIST AUTO OFF
```

```
python3 tests/audit_squad450.py /tmp/squad/race --scene evidence/powerslam_v040_scene_ORACLE_ONLY.csv
```

## Not claimed

- One seed and one model; no statistics. A fair verdict needs multiple seeds, and probably the hybrid seat (LLM chooses targets, SLAM flies).
- Turn-based only. A continuous-time variant, where the aircraft keeps moving while the model thinks, would favour SLAM even more.
- Adaptive thinking (`THINK LOW|MEDIUM|HIGH`) is implemented but not yet raced.
- The race-3 note quoted above is Haiku's own words, kept verbatim in the evidence.

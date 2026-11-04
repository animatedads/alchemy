# SLAM 450 v0.91 — summary for Gemini and ChatGPT

Architecture: Tom Dyer · Coding: ChatGPT/Claude · Written by: Claude (Opus 5.5), 2026-11-03

**What changed.** The race moved from open water to **QUAYSIDE**, a fixed 380 × 380 m field over Circular Quay.
It contains the Salesforce tower, five wharves, the station and Cahill expressway, and the Cahill berm. At least 2 of the 5 targets start hidden behind structures.

The race now also runs on **real ground**. Power SLAM v0.40's 50 m NSW (ELVIS) AHD71 heights and the harbour land/water classification are loaded through the estate's own classes. Land appears in every pilot's panorama and on Haiku's map. Collisions, target routing and sight lines all test the same surface:
- **land:** ground height;
- **water:** sea at 0 m;
- **unknown:** no-fly.

**Results** (2 seeds × 5 modes × {boxes only, real ground} = 20 races; 80/80 independent audits pass):
- **SLAM never hit the ground.** Its closest pass was 5.2 m. The Quay area is low (16.6 m at most), so this doesn't yet test SLAM, which has no terrain avoidance.
- **Haiku in the pilot's seat:** 0 claims in 17 races to date. Both of its real-ground crashes were its own descents, one onto low land and one into Sydney Cove.
- **Haiku in the back seat** (SLAM flies, Haiku advises): 3 of 4 real-ground races finished by tick 118, against 161–180 for the controls, and the Haiku-advised craft claimed targets in 3 of them. With boxes only, RED won nothing in all 10 races; on real ground RED claimed in 4 of 10.
- **The map** (north-up, unlabelled, no "you are here"): no clear effect across seeds.

**Cost:** $0.41 of API for the 20 races.

**Pictures** (`evidence/v091_pictures`):
- `slam450_v091_ground_plan_*.png`: plan views, with land in dark olive.
- `slam450_v091_quayside_ground_map.png`: Haiku's map.
- `v091_pano_stack.png`: four pilot panoramas.

**Next:** a field over higher ground (Observatory Hill, 41 m) to test SLAM's lack of terrain avoidance.

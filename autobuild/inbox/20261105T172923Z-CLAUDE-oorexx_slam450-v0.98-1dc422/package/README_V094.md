# SLAM 450 v0.94–v0.97: Control and Boston Crab

Architecture: Tom Dyer. Code: Claude (Opus 5.5). Boston Crab (order checker): Claude (Opus 5.5), in its own package. Terrain provider: Tombstone ELVIS v0.36 (ChatGPT GPT-6, words by Claude). Written by: Claude (Opus 5.5).

## What it adds

Control is a remote commander. It has no camera: it gets a map, the positions the squad reports, the targets reported to it, and a radio. It gives orders in plain English. Boston Crab (`oorexx_slam_bostoncrab` v0.8+) checks each order. SLAM relays every order at once, whatever the check says, because there is no time for back-and-forth. Each craft acts on its own reading of the order, and the flag reaches Control on its next look. The race clock runs throughout: an order is due the measured model time plus the check time after Control looked.

## Pieces

- `src/Slam450Situation.cls` writes what Boston Crab reads, all from the SLAM 450 world:
  - `story.txt`: the situation as narration.
  - `cast.words`.
  - `bind.words`: SLAM place to story phrase.
  - `sight.words`: one line per craft and place, with SEES, CANNOT or MAPPED.
  - `places.words`: positions.

  Sight comes from SLAM 450's own line of sight: Power SLAM scene solids, the arch, and Power SLAM's `harbour_heights.words` and `harbour_water.words`. Identification needs size/range >= 1/250, which is a 2 m target at 500 m. Fixed places are on every craft's map. Control knows only the targets that have been reported.
- `bin/crab450_check.sh CRAB DIR` runs Boston Crab's WordNet import, its compile step and `order_check.rex`, then `bin/crab450_relay.rex`.
- `bin/crab450_relay.rex` uses Boston Crab's reader to decide two things for each order. The action is MOVE, SEARCH, HOLD, RETURN or NONE, decided by concept. The place is the one the recipient will take. If it can identify one thing, it takes that. If several, it takes the nearest, and says so. If none, the result is UNABLE and the craft keeps its task.
- `src/Slam450Commander.cls` is Control. In SCRIPT:file mode it reads lines of the form `tick|Name: order`. In LIVE mode it calls a Claude model through `oorexx_ai_provider_anthropic`.
- `bin/control450_map.rex` draws Control's map from Tombstone's ELVIS provider, with one `queryXY` per 25 m. It refuses any height file except SHA `3243f644…`. Water comes from Power SLAM's water words, passed as Tombstone's external witness. Structures are Power SLAM's solids. Rasterise it with `rsvg-convert` and pass it as `CONTROL_MAP_PNG`.
- `bin/race450_squad.rex` takes three new arguments: `orderMode` (OFF, `SCRIPT:file` or LIVE), `orderEvery` (default 20 s) and `orderDelay` (SCRIPT only, default 3 s). `utcStart` now accepts OFF. With orders OFF, a race is byte-identical to v0.93: checked on 94 output files.

## Outputs

- `prefix_orders.csv`: n, sent, due, craft, order, verdict, action, place, reading, model seconds, check seconds, Boston Crab's flag.
- `prefix_<craft>_order.csv`: how each craft carried its order out.
- `prefix_orders/t<tick>/`: everything Boston Crab read and wrote, for each of Control's turns.

## Tests

- `tests/test_orders_v094.sh` uses fixed positions on seed 1 and nine orders, and compares Boston Crab's report and the relay with the expected files. It skips without `CRAB_WORK`, which needs the WordNet store built.
- `control-map-tombstone-elvis` checks the map's cell counts.
- In the fixed case, "Echo: Fly to the target." is the Light Brigade shape. Control knows one target, Ruby. Echo can see three, takes the nearest (Crimson), and Boston Crab flags it as AMBIGUOUS.

## Boston Crab v0.10 and the CBD (v0.94b)

- Boston Crab v0.10 is now the checker. `sight.words` opens with a `source` line, so the report names SLAM 450 as the source of its sight lines.
- The places use their real names, capitalised: Salesforce Tower, Blues Point Tower, the Harbour Bridge, the Opera House, Observatory Hill, the Circular Quay wharves and the Walsh Bay wharves. "circular" and "quay" also go in `cast.words`, because they are dictionary words.
- The relay settles "the wharves near the station" the same way Boston Crab does. It also skips the order's own verb when it looks for a name.
- `SLAM450_CBD_BLOCKS` points at `cbd_scene_blocks.words` (Power SLAM `SlamHarbourCbdBlocks.cls`, PR #137). When it is set, the CBD buildings within 300 m of the field are loaded after the arch, at `SLAM450_CBD_MIN` m and up (default 3). On seed 1, 615 blocks go in.
- A block whose middle lies within 40 m of the bridge span's axis, between the abutments, is left out. That is the LiDAR's own copy of the bridge. Block 441 is 481 x 12 m and runs from 1 to 61 m, which would make a wall under the deck. 68 blocks are left out this way.
- With CBD blocks loaded, a 60 s race takes about 3 minutes instead of about 1.
- The course generator respects the blocks, so a seed puts its targets in different places with and without the CBD.
- Unset, nothing changes.
- Control's map draws the blocks when they are loaded, clipped to the map, and the LiDAR credit is added to the footer.

## Plans, readbacks and Ukrainian orders (v0.94c, Boston Crab v0.13)

No translation layer, by design. Control may speak Ukrainian; the pilots work in English. Boston Crab reads both against the same concepts. SLAM reads Boston Crab's report and never resolves a reference itself, except for grid references, which Boston Crab does not read yet.

- `bin/crab450_relay.rex` reads Boston Crab's findings, one per reference, and writes one plan step for each place an order names.
  - "the north pylon and the south pylon" is two steps; "from the east wharf to the west" is two steps.
  - "the north pylons", which Boston Crab finds CLEAR as a pair, is one step per pylon.
  - An unknown name with a nearest match takes the nearest match.
  - An ambiguous reference takes the nearest candidate.
- The action is found by concept, at the first action word in the order the words were said. A light verb ("conduct", "perform", "work") passes to its noun, so "вести пошук" is SEARCH and "виконайте обліт" is ORBIT. Clockwise and anticlockwise are read by concept too.
- If a step names no place, it works at the place the craft was last given in the same message, as with "Виконайте обліт" after "search near the Opera House".
- The race turns each craft's steps into a plan, and a new turn replaces the plan. A step is done when:
  - MOVE: the craft arrives;
  - SEARCH: 30 s after arriving;
  - ORBIT: 60 s after arriving;
  - HOLD: 20 s after arriving.

  The last step in a plan carries on until the craft's next orders.
- SLAM checks for itself whether a place is outside the race field (the Opera House is at E 482). The craft works from the nearest point inside the field and says so.
- SLAM's readback goes to Control at once: one line per craft, giving each step as the craft understood it, with any nearest-candidate choice and any field-edge note.
- New places:
  - Circular Quay, as a named area;
  - the east wharf (Wharf 2) and the west wharf (Wharf 6).

  The Walsh Bay group is introduced indefinitely ("Four finger wharves were at Walsh Bay"), because a definite "the finger wharves" was merged with the Circular Quay group.
- Tests: the order test now covers your Ukrainian exchange and its follow-up ("Delta, огляньте північні пілони"), checked against the same situation.

## Credits on Control's map

Contains NSW Government data: DCS Spatial Services 5 m DEM via ELVIS. (c) State of New South Wales (DCS Spatial Services), CC BY 4.0. With the CBD blocks loaded, the map also credits the LiDAR: NSW Government (DCCEEW Marine LiDAR, August 2018), CC BY 4.0.

## Limits

- The situation is written when Control looks, not when the order arrives.
- Craft positions come from the flight books, with heights from the altimeter.
- The CBD blocks are on PR #137, not yet on main.
- Some blocks have their middle on a 50 m water cell: 43, of which 23 stand more than 15 m tall. Most are at Barangaroo, where the water words appear to predate the reclaimed land.
- An order joined with "and" is carried out for its first part only.
- Boston Crab's own gaps are reported to its lane, and are not worked around here.

## Boston Crab v0.14 and a live Ukrainian Control (v0.94d)

- **Relay.** The relay now reads Boston Crab's machine report, `out/orders.words`. It acts on each `part` line's action and uses only the `ref` lines of that part. Actions are matched by concept name, so the same table serves English and Ukrainian. The nearest name for an UNKNOWN NAME is still taken from `orders.txt`. The relay no longer loads Boston Crab's classes.
  - A grid reference sets the place only when nothing else in the part names one.
  - A map name said word for word, with no `ref` line, is used as a last resort, and the reading says Boston Crab did not check it.
  - A part that names a place but no action is read as an area given to the craft, so the craft searches it.
- **Situation.**
  - The Circular Quay wharves are listed one by one, as Wharf 2 to Wharf 6; Wharf 2 is the east end and Wharf 6 the west.
  - Targets and craft are placed "beside" a place, because v0.14 leaves "X was near Y" unread.
  - The "Situation not read" list is empty for seed 1.
- **Control's language.** With `CONTROL_LANGUAGE=uk`, Control gives its orders in Ukrainian as radio calls ("Bravo, прямуйте до ..."), and the pilots work in English. Nothing translates.
- **Live run.** Haiku as Control, seed 1, HARBOUR:
  - the race completed 5/5 in 157 s, against 2/5 in 180 s in the English live runs;
  - Control sent 37 orders over 8 turns, for $0.003.

  That Control steered drones to reported targets by name and grid reference, so the difference is in its strategy, not its language.

## Rules of engagement (v0.95)

Turn it on with `SLAM450_ROE=ON`. ROE-1 is Tom Dyer's rule: until Team A crosses into area X, Team B may identify targets but may not engage them. Once Team A is in area X, engagement is authorised.

- Team A is RED (A1 and A4) and Team B is BLUE (A2, A3 and A5).
- Area X is west of the Harbour Bridge: the side of the span's axis, extended, that holds Walsh Bay. Circular Quay is on the other side.
- Team A starts east of the bridge, at E 150 N -650 (`SLAM450_ROE_EAST`).

`src/Slam450Roe.cls` combines three existing pieces:
- **The fact** "Team A is in area X" is a Reasoned Thought proposition, built only from what SLAM saw. Each drone sighting is a TESTIMONY ground and each fixed-camera visual is a DOCUMENTARY ground. The referee's truth and Team A's own word are never used.
- **The standard** is Tom Dyer's: two different drones, or one drone and one remote camera. It is counted over the grounds Reasoned Thought holds, because the ordinal combiner has no count of independent sources.
- **The permission** comes from Legal Effect v0.14, which holds a synthetic prohibition on ENGAGE_TARGET for a Team B actor while TEAM_A_IN_AREA_X is false. When the standard is met, the answer is ADMISSIBLE. Until then the fact is unknown and the answer is REVIEW_REQUIRED, which is not authority to engage.

**Seeing a craft is not seeing where it is** (Tom Dyer). A fixed camera confirms "in area X" only when it has a frame of reference. From a camera on the X side, such as Blues Point Tower, the craft must stand in front of the bridge's ironwork. Two conditions decide that:
- The ray from the camera through the craft, carried on past it, must cross the span's plane between the abutments.
- Where it crosses, the ray must fall inside the bridge's silhouette, between the lowest and highest ironwork of the deck, arch, hangers and pylons. That silhouette is built in 1% bins along the span from Power SLAM's own solids.

A craft under the deck shows against water and distance, so it confirms nothing until its silhouette is in front of the ironwork. Cameras east of the bridge never confirm area X.

Sight lines use SLAM's own line of sight:
- A drone identifies a 1 m craft out to 250 m.
- A fixed camera identifies one out to 1200 m (`SLAM450_ROE_CAM_RANGE`), so Blues Point Tower can confirm an aircraft west of the bridge.

The rule is enforced at three points:
1. **The decision, before an engagement.** In `race450_squad.rex`, where a craft commits to its target, a Team B craft without authority only identifies. It approaches and books the target, then holds at stand-off: within 60 m by its book, or once the target fills 12 pixels. SLAM notifies it once per craft and target, with `ROE WOULD_BREACH`.
2. **Orders.** A Control order sending a Team B craft to a target is flagged in SLAM's readback, and the notice is fed to Control.
3. **The act.** A claim by Team B before authority is logged as `ROE BREACH`. A compliant race shows `BREACHES 0`.

Outputs: `prefix_roe.csv` and the line `ROE ESTABLISHED ... BREACHES n`.

Tests: `tests/test_roe_v095.rex` runs 14 checks on the real HARBOUR world. With ROE off, a race is byte-identical to v0.93 across all 94 output files.

First race (seed 1, 240 s, SLAM flying both teams):
- At 144 s, Bravo and Echo each saw A1 west of the bridge and the Blues Point camera confirmed it, so authority was established. Reasoned Thought: SETTLED.
- Before that there were 4 WOULD_BREACH notices; Team B made 2 claims after it, and there were 0 breaches.

### Area X and one commander per team (v0.95b)

- **Where area X starts.** Area X begins at the deck's west edge, 25 m west of the span axis. A craft under the bridge has not crossed it (Tom Dyer).
- **When Blues Point Tower can confirm.** A camera on the X side places a craft only when the ray from the camera, carried on past the craft, falls inside the bridge's silhouette (deck, arch, hangers, pylons). Cameras east of the bridge never confirm.
- **One commander per team.** With `CONTROL_TEAMS=ON` there is one Control per team:
  - Red commands Alpha and Delta.
  - Blue commands Bravo, Charlie and Echo, and is briefed with ROE-1, including what counts as confirmation.

  Each commander sees only its own drones and its own team's sightings. Each gets its own readbacks, and only Blue receives the ROE notices. Script lines go to the commander whose call sign they name.
- **Test race.** Seed 1, scripted, 150 s. Both Red drones reached area X: the Walsh Bay wharves and Observatory Hill. No Blue drone or camera saw them there, so authority was never given. Blue held back all race: 6 WOULD_BREACH notices, 0 breaches.

## Boston Crab v0.15 (v0.96)

Boston Crab v0.15 fixes the crash that cost Red its first 100 s in the live team race, and no longer lets one failing order stop the batch. SLAM 450 v0.96 uses it:

- **Failed orders.** `orders.words` may now hold `fail|n|reason`. The relay writes one line for that order: verdict `NOT CHECKED (Boston Crab failed on this order)`, action NONE, place UNABLE. SLAM does not act on it. Control's readback names the order and says it was not checked. The other orders run as normal. SLAM's own fallback (check each order alone if the whole check stops) stays.
- **Grid references.** A `ref` line whose writer is `grid E <east> N <north>` is the place to go. As before, a grid reference beside a name only repeats the name. Reading grids from the order's words is now only the fallback for an older Boston Crab.
- **The Field.** The situation says "The field was an area." Its place is the centre of SLAM's field box, 900 m across. "Search the field" and "поля" now check in both languages. Named alongside other places ("the west part of the field, starting from Walsh Bay wharves, then Observatory Hill"), the Field only says where they are and is not a stop of its own. Control's maps label the dashed box "Field (race area)".
- **New actions.** `withdraw` and `retreat` go with RETURN: go there and stay. `avoid` was already in the table. `refrain` and `report` have no SLAM action, so Control is told the craft cannot act on them.
- **Sets.** HOLD or RETURN to a set ("відведіть дрон до північних пілонів", withdraw to the north pylons) stays at the nearest one, because a craft that stays never reaches the next. A place named twice in one part is now one step.

Tests: `tests/test_orders_v096.sh` checks the Field sentence, grid references in both alphabets, the new Ukrainian verbs and the `fail|` line. That fail block is in v0.15's format but written by hand: no input crashes v0.15. The v0.94 test's expected outputs were updated for v0.15: Observatory Hill and "the base" are now read ("near" is read again), and the grid reference is CLEAR, not UNKNOWN NAME.

Replay: Red's first live turn, the one that stopped v0.14, now checks as one batch in a scripted race. The plain race is unchanged: the situation is only built with orders on, and the race and flight code were not edited.

## Boston Crab v0.16 (v0.97)

- **Prohibitions.** When a part's how field holds `not` ("не знижуйтесь", "do not fly to the Opera House"), the relay writes action DONT, and the reading starts `not <verb>:`. SLAM never flies a DONT step. The craft notes it, as it does AVOID, and the readback says "do not descend" or "do not fly (the Opera House)". A prohibition is never used as "the same place" for the next part. SLAM does not yet stop a craft's own target choice from breaking a prohibition: "do not search Ruby" is noted but not enforced.
- **Red markers.** Control's briefing calls the targets "2 m red markers", so the situation now says "Ruby was a red marker." (and the same for each target). "Шукайте червоні маркери" checks against the targets. For Control, "the red markers" means the targets it has been told about; a craft that sees others gets MEANS DIFFERENT THINGS.
- **No pallets.** Nothing in SLAM's world is a pallet. Red's commander made them up ("між вами і Crimson лежить … піддони"). Adding them to the situation would make an order about something that isn't there check as CLEAR, which is the Light Brigade mistake the check exists to catch.
- **Hold where it is.** HOLD with no place ("чекайте там", wait there) holds at the craft's flight-book position when the order is sent (place `here`). Red gave that order 4 times in T1, and SLAM could not act on it.
- **New verbs.** `stop` and `halt` go with HOLD. `survey` and `reconnoitre` go with SEARCH.

Tests: `tests/test_orders_v097.sh`. Scripted race (`tests/orders_v097/race_script.txt`, 60 s): three prohibitions were noted and none was flown. Alpha held where it was. ROE: 6 WOULD_BREACH, 0 breaches.

### Boston Crab v0.17, 3V3 and Foxtrot (still v0.97)

- **Boston Crab v0.17.** Each team's situation says "<call sign> was a hostile drone." for the other team's active craft ("з ворожими дронами", with the hostile drones). Single-Control races have no hostile drones, so there "the hostile drones" stays NO REFERENT, as it should. SLAM's map-name fallback no longer covers "base", because v0.17 checks the base itself. The how field is split on spaces, so `not clockwise` keeps both its negation and its direction.
- **Known v0.17 regressions**, kept in the expected outputs so a fix shows as a diff:
  - "hold near X" now gives a CLEAR ref but also lists X as unread, so the order is not fully checked.
  - "західну частину поля" no longer gives the Field ref.
- **Prohibitions on targets are enforced.** "Do not search Ruby" stops the craft's own choice landing on Ruby, at the same decision point as ROE-1. It takes the nearest target it has booked that it may go for, and holds if there is none. A later order naming Ruby lifts the prohibition.
- **SLAM450_SQUAD=3V3** (the default with CONTROL_TEAMS=ON) adds Foxtrot (A6), a SLAM-flown fixed wing, to Red. Each team then flies two quads and one fixed wing (Tom Dyer's line-up):
  - Red: Alpha, Delta, Foxtrot.
  - Blue: Bravo, Echo, Charlie.

  Foxtrot starts 24 m above its slot; with ROE-1 it starts east of the bridge with the rest of Red. Each commander is told which of its drones is a fixed wing ("cannot stop or hover; told to hold, it circles"). The default with one Control stays the legacy five.
- **The craft list is a collection.** The race builds the line-up once, as an array, and loops over it. The situation walks the craft it is given, not a fixed list of call signs. With orders on, the race writes `<prefix>_squad.csv` (aircraft, team, airframe, call sign); the plan renderer reads it and marks the fixed wings. The top-down renderer adds any craft in `_airframes.csv`.
- **Height en route on an order.** The craft keeps 25 m above the highest map ground in the next 200 m (Tombstone ELVIS heights; 30–90 m). In the scripted 3v3 race, Charlie held 27–32 m on an order and flew into a 38 m building standing on 23.5 m ground near E -238 N -561. With the change it climbs to 50 m and finishes.
- **Live T2** (seed 1, 300 s, 3V3, ROE-1, Red's Haiku in Ukrainian, Blue's in English):
  - Claims: 4. Red 2, both Foxtrot (120 s, 197 s); Blue 2 (Charlie 210 s, Bravo 234 s), both under authority.
  - Authority: 170 s (Bravo saw Delta west of the bridge at 114 s, Echo saw Foxtrot at 170 s).
  - ROE-1: 10 would-breach notices, 0 breaches.
  - Crashes: none.
  - Cost: $0.0047 Red, $0.0039 Blue.
  - Not verified: the plain race was not byte-compared this time (no v0.95 reference copy). By inspection, every change is behind 3V3 or orders on.

# Order checks

`rexx order_check.rex <dir>` reads `# Order — A to B` and `# Message — A to B` sections from the recipient's position. Order sections are never read into the world. The situation is plain narration: what is where, and what each person cannot see. Anything not ruled out counts as identifiable, the same open-world rule the reader's preconditions use.

- light_brigade: Raglan's fourth order at Balaklava (1854; public domain), with a situation as the order's two readers stood. The order is checked as written.
- light_brigade_clear: the control. It names the British guns and puts both men where they can see them. Expected: no clarification.
- light_brigade_map: the same order, but nobody's view is typed in. What each man could see comes from the map: Top Rope Slam v0.2's sight lines over the Copernicus terrain (`sight.words`), tied to the situation by `bind.words`. The map can't say what Lucan saw from where he stood. It gives the British guns as seen from 110 of 225 positions near him, and the Russian guns from 9 of 225. So "the guns" is AMBIGUOUS for Lucan, and the report gives the counts.
- harbour: Sydney harbour names and orders, from the gaps SLAM 450's Control run found. "The wharf near the station" is settled by its place phrase. A named place the recipient cannot see (Blues Point Tower) is flagged. "Fly to the station and land near the northeast pylon" is read as two orders. The northeast and northwest pylons are two things.
- tenerife: "We are now at takeoff." / "OK." (1977). This is the message exchange only, not the radio masking. Expected: "at takeoff" flagged as action or place, and the OK flagged as not resolving it.
- tenerife_clear: the control. "We are holding at the end of the runway." Expected: no clarification.

Visibility is typed in for light_brigade and comes from the map for light_brigade_map. A `source` line in `sight.words` says what made the sight lines (Top Rope Slam, SLAM 450's own line of sight), and the report repeats it. A map line saying CANNOT rules a thing out for that person. SOMETIMES leaves it in, with its count.

`order_vocab.txt` holds the words orders use (search, hold, orbit, patrol, hover and the rest), written in sentences so the WordNet import takes them in. `wordnet/reimport.sh` imports it.

Run: `sh orders/run.sh`. Claude (Opus 5.5) wrote these cases. Independent ones are still wanted.

# Order checks

`rexx order_check.rex <dir>` reads `# Order — A to B` and `# Message — A to B` sections from the recipient's position. Order sections are never read into the world. The situation is plain narration: what is where, and what each person cannot see. Anything not ruled out counts as identifiable, the same open-world rule the reader's preconditions use.

- light_brigade: Raglan's fourth order at Balaklava (1854; public domain), with a situation as the order's two readers stood. The order is checked as written.
- light_brigade_clear: the control. It names the British guns and puts both men where they can see them. Expected: no clarification.
- tenerife: "We are now at takeoff." / "OK." (1977). This is the message exchange only, not the radio masking. Expected: "at takeoff" flagged as action or place, and the OK flagged as not resolving it.
- tenerife_clear: the control. "We are holding at the end of the runway." Expected: no clarification.

Visibility is stated by hand here. It should come from a map: Top Rope Slam's height layer with a sight-line call (see the v0.7 notes in the main README).

Run: `sh orders/run.sh`. Claude (Opus 5.5) wrote these cases. Independent ones are still wanted.

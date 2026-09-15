# Requalification evidence summary — 2026-08-28 19:19 roll-up

The Staff Banking recovery components were exercised against the current 19:19 roll-up closure rather than accepted solely from the earlier v0.2 transcript.

Results:

- Staff Authority v0.2 domain/integration: 10/10 PASS.
- Staff Authority Service v0.2: 9/9 PASS.
- Intermediary Staff Authority v0.1: 6/6 PASS.
- Staff Channel v0.1: 8/8 PASS.
- Staff Channel Service v0.1: 9/9 PASS. The deepest relationship→service→core test and runtime-module test both pass when isolated; an earlier combined debug invocation exhausted the outer execution window rather than producing a product failure.
- RID Wire UI using Wire UI Server v0.17 and Crypto v0.5: 4/4 PASS.
- Actual Alchemy browser→WebSocket Web Gateway→Queue Fabric→RID Wire UI→signing→browser projection: 1/1 PASS.

Existing-baseline total: 47/47 PASS.

The new Staff Method Permissions v0.1 then adds 7/7 PASS, taking the Staff Banking v0.3 candidate to 54/54.

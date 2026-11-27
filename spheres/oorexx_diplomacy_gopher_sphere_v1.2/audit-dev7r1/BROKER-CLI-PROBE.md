# Additional offline operator CLI probe
After dev7r1 was staged, the actual operator entrypoint tools/live.rex was
run on native ooRexx 5.3.0 r13196 using published SecretBroker v0.2 and
Alchemy Objects v0.8 (the broker declares v0.7, which was not recovered as
an exact standalone tree). The transport executable was replaced on an
isolated PATH with a deterministic local fake curl (fixture credential,
no network). It inspected the request and credential stdin, returned
Haiku-shaped JSON with explicit fixture model identity and usage, and
supplied memory on press calls and hold orders on movement calls.

Result: FINISHED 1901, 5 phases, 42 press calls, 14 order calls, 56 operator
statuses OK, zero invalid orders. Separate focused broker probe returned
HTTP 200 and zero active leases. This tests the CLI and actual broker with
v0.8 under a fixture, not the exact v0.7 dependency and not an API call.
The actual runtime profile pins, authorized credentials/network and live
game year remain open.
Ordinary tools/game.rex replay command also passed byte-identical replay
without the broker or provider. Journal SHA-256:
9b8095aeb6f4a8f66df79975276d0f52e56a565201ffafea688063867d8f403c.
Exact Git blobs for probe dependencies: SecretBroker b44f3a6dbf30e710547581a45bf952e23def6558;
AlchemyObject b1f589f83aad5d646ee14a5c9d909c8ef2392fe2;
AlchemyEvidence 4f674c6f26c7b506de1e02af53c34e6016770b9c;
AlchemySecurity 7df2b2424c80d4c8ef2987f68388ca8e76af4a8d;
AlchemyLockedMethod 7aab217f059ee9b44bf73b65bc379bcc52c7c998.

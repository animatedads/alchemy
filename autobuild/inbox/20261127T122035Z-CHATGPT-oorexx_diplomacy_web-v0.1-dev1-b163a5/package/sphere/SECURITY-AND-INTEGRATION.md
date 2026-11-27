# Diplomacy Web consumer — development status v0.1-dev1

Scope: public competition experience; engine pinned to dev6 source for equal
designer disclosure. No engine source changes. Architecture: Tom Dyer.

Positive-list projection:
- LAB reviewer: non-playing owner, delivered press and committed public evidence;
  edits its own LLM instruction drafts in lobby only.
- Human seat: only its own active task and delivered mail involving its power.
  Cannot read a sponsored profile, another player's orders, private reasoning,
  press addressed elsewhere, raw source call logs or private address books.
- Sponsor: credential ownership only; selects independently sealed profiles;
  cannot write opponent instructions, cannot select self-authored profile.
- Observer: public committed board/results only. No private press or prompt data.

System principal must originate from the verifying identity service, never a
request detail. One identity cannot join multiple player seats in a non-LAB
game. Task broker rejects wrong principal, stale task, duplicate submission,
and late submission after expiry. Profile IDs are not instruction access.
Use fresh Wire session/queues after real login/logout and prevent cached
private projection. The loopback fixture demonstrates semantics, not real
multi-user identity isolation.

Evidence on ooRexx 5.3.0 r13196: 55 domain checks, 17 human task checks,
deterministic native source framing/crypto test; actual Wire v0.17, Queue
Fabric dev6/gateway v0.2 and JS dev6: 19 checks. Chromium browser binary absent:
browser layout/DOM suite not run. Not publicly admitted or installed.

Next gate: public realm and credential provider, real native HTTPS/WSS
session bootstrap, immutable durable per-game roster/journal, human task
deadline and scheduler, engine/provider and designer job integration, real
multi-session hostile-client and browser qualification. Use Secret Broker
v0.2 with approved server-side encrypted storage; broker itself is not a vault.

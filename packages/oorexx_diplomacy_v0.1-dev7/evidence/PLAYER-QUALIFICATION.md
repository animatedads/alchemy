# Step 7 — offline qualification candidate

Architecture: Tom Dyer. Implementation: ChatGPT (GPT-6.2); independent
step-5 review and rich stub/auditor: Claude (Opus 5.5).

Interpreter: supplied ooRexx 5.3.0 r13196.
Unchanged production referee and rules: evidence/production-identity.sha256.
Prior assertions 3311 referee (232 positions), 63 game, 276 press.
New player protocol/provider tests: 189 assertions. One game year with
42 press and 14 movement order calls via the stateless mock provider.
New transport checks: 12 assertions, fake curl with synthetic credential
only, including actual process deadline, exact request bytes and lease retirement.
Native focused tests pass; canonical player/replay journal SHA-256:
d28383aa244f73e4b2b96ee75cf279419d2a72dfce32f0966a40a2ebe404db47.
Full gate additionally runs Claude's rich audit on seeds 1000–1004, each
game run twice and replayed; preserved exact upstream audit under review/upstream.
The gate is offline; actual Secret Broker-backed network integration and the
one-live-year requirement have not been exercised, pending Architect pins,
credential and network authorization. No API-key or live-model claims.

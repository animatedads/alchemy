# Diplomacy web consumer — v0.1-dev2

Architecture Tom Dyer. Consumes engine v0.1-dev7r1, no referee modification.
The non-playing LAB owner can review all delivered press; seated humans and
delegated players cannot view any other player's instruction or current order,
and only own sent/received delivered press. The human-game owner does not get
reviewer privileges. Public results are released after adjudication; press
after all round submissions are collected. Sponsored opponents require an
independent sealed profile; profile label/seal is not instruction access.

Production must bind authenticated user to immutable native session and
unique queue principal. DiplomacyWireIngress verifies queue-bound AP,
application and session against every envelope, before calling app.receive.
Separate views/queues prevent private projections from being mixed. Do not
reuse fixture's identity-switch action. Public registration and revocation
are separate estate identity integration.

Native worker freezes all-human roster, uses only existing detached task
frames, issues game-scoped one-shot capability, rejects foreign/stale/late
submissions, and waits asynchronously. Task duration is bounded. This version
runs a real one-year game under dev7r1 (sequential source callbacks, round
barriers). Canonical journal ingress is trusted-only, worker stores journal
in a fresh private directory; production has not yet established durable
database nor restart recovery.

Exact developer disclosure includes all 11 dev7r1 src files and four core
data files, whose SHA256 hashes match the official package manifest. No
credential, user prompt or private exchange is in that bundle. Real provider
admission and expenditure remain gated. The native phase engine does not
receive a new legal order oracle or other referee bypass.

See README, VALIDATION and deploy/ED209M.md for precise status.

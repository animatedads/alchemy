# Rasen Falcon Diplomacy competition web v0.1-dev2

Architecture: Tom Dyer. Implementation: ChatGPT. Target:
`diplomacy.rasenfalcon.com`, ed209M (owner-reported current DNS points via
newyork1.rasenfalcon.com to 185.195.106.30). DNS evidence is not a live
application, SSH identity or TLS verification.

This is an ooRexx Wire application consumer, not a second Diplomacy referee.
It consumes the unchanged estate Diplomacy controller v0.1-dev7r1.

## Delivered

- Responsive game room: original schematic deployment, complete textual unit
  ledger, centre ledger, committed results, delivered press, lobby, seat setup,
  prompt studio, model credential profiles, account and order/press desk.
- Native registry: LAB (seven LLM seats; non-playing orchestrator), MIXED
  (human/delegated seats and sponsored opponents), HUMAN (seven independent
  human seats). No global user/game count cap.
- Host-bound identity sessions and game-scoped task capabilities. Seven player
  seats freeze when an admitted human worker starts; duplicate start and roster
  revisions fail closed. This does not grant the lobby owner reviewer privileges.
- Actual dev7r1 game worker: source callback -> private task -> literal submitted
  response or timeout -> unchanged referee. Worker runs on a separate Rexx
  activity; game and queue access remain responsive. It issues tasks through
  the existing controller, which invokes powers sequentially, **not** simultaneous
  deadline windows. The referee releases press only after a complete round and
  movement results only after completing adjudication.
- Task projection positive-list contains only detached text and nested arrays;
  private numeric address book, inbound mail and remaining time per task. No
  legal order generation, opponent submissions/instructions, private address
  books of other seats, raw journal or vault data. The server owns expiry and
  task consumption. A human can enter an empty press submission.
- Separate native Wire view/application for each host-authenticated principal;
  queue ingress checks the complete envelope against the actual server-bound
  access point before dispatch. Queue principals must be distinct. Tests use
  actual Queue Fabric and Wire application messages, including fully forged
  victim envelope and forged principal fields. Never route an untrusted queue
  message by its claimed applicationId.
- Credential/profile ownership; sponsored opponents use independently sealed
  prompts and the sponsor cannot view or edit them. LAB owner is a non-playing
  reviewer and can edit its own LLM prompt drafts in the lobby. A player or
  mixed-game creator with a player seat only sees its own correspondence.
  Observers receive no private press.
- Exact equal designer source: all eleven dev7r1 source classes plus initial
  deployment, map, lifecycle config and rules (15 files). Native bundle builder
  validates every source hash and frames immutable bytes. Provider calls remain
  closed; separate designer and runner credential references are modelled.

## Local qualification

Set OOREXX_HOME to ooRexx 5.3.0 r13196. For the baseline single-session browser
fixture, set WIRE_ESTATE to a directory containing wire_ui_server_v0.17,
alchemy_objects_v0.8, oorexx_crypto_v0.8.3, oorexx_queue_fabric_v0.9-dev6,
oorexx_queue_fabric_web_gateway_v0.2, alchemy_wire_ui_js_v0.4-dev6.
Run dev/run.sh and open its loopback URL. This fixture is deliberately NOT an
internet account/session system and never accepts real API keys. The default
lab data is synthetic; it does not demonstrate a live model or referee.
Separate native tests/run.sh uses the real controller, seven separately bound
scripted human sessions, and real estate queues. See VALIDATION.txt.

## Host admission (not yet live)

See deploy/ED209M.md and sphere/SECURITY-AND-INTEGRATION.md. The worker requires
a host-admitted config, seed, private exclusive per-run journal directory and
a bounded task deadline. This package does not implement durable account/game
storage, restart/rejoin recovery, public account verification, encrypted key
storage, live vendor calls, public TLS/WSS or remote installation. The estate
identity service, native HTTPS listener, Secret Broker and General Deployment
are the required integration authorities. The native worker is not permission
to spend money or expose a public route. Don't deploy dev/run.sh on ed209M.

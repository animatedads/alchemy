# Rasen Falcon Diplomacy competition web v0.1-dev1

Architecture: Tom Dyer. Implementation: ChatGPT. Target: diplomacy.rasenfalcon.com.
A separate Wire application consumer, not a second implementation of the game
or any change to the qualified ooRexx referee.

## Delivered
- Responsive browser game room with original schematic deployment, centre
  ledger, released adjudication and delivered press; game lobby, setup, model
  credentials, prompt studio, account and human order/press desk.
- Native domain registry with three modes: LAB (seven LLM seats, one non-playing
  orchestrator), MIXED (human/delegated seats and sponsored opponents), HUMAN
  (seven independent human seats; no global user/game count limit).
- Native verified-principal, credential ownership and seat authorization.
  Credential registry stores opaque vault handles, never projects those handles.
- AI opponents use independent host-admitted sealed profiles; author cannot
  sponsor its own profile as an opponent. Sponsors cannot write or retrieve
  opponent instruction text. Only own LLM instruction drafts in a lobby may be
  viewed/edited; LAB reviewer is exclusively a non-playing role.
- Journal projector positive-lists committed public state, adjudication, and
  delivered press. No raw journals, call bodies, instructions, private model
  reasoning, current orders, numeric private address books or vault handles.
  MAIL is buffered until PRESS_END; phase state is buffered until PHASE_END.
  For non-LAB participants only own sent/received mail; observers no press.
- Native one-shot task broker: authenticated human seat, server-scoped task ID,
  no opposing current submission, strictly literal raw input, sealed response,
  duplicate/stale/wrong-principal rejection. Host must bind broker to a game and
  worker; no pretend live task is generated in the demo.
- Exact designer-source pin: all eight dev6 source classes plus game/rules/map/
  initial data; expected SHA-256 of every member and native immutable byte
  framing and SHA-512 digest. Every designer must receive identical bundle
  bytes; model credentials for design and play can differ. No user-provided paths.
- Real loopback ooRexx → Wire Server → Queue Fabric → existing gateway → Wire
  JS access point. Browser emits validated UI_ACTION messages, not a second
  HTTP business API. Local Node edge serves static/bootstrap files only.

## Run fixture
Set OOREXX_HOME to exact ooRexx 5.3.0 r13196. WIRE_ESTATE is a directory containing
wire_ui_server_v0.17, alchemy_objects_v0.8, oorexx_crypto_v0.8.3,
oorexx_queue_fabric_v0.9-dev6, oorexx_queue_fabric_web_gateway_v0.2,
alchemy_wire_ui_js_v0.4-dev6 (the local demonstrated access-point package).
Run dev/run.sh and open the reported loopback URL. The default experiment data
is explicitly a synthetic test fixture; not game output. Register test identity,
create a lobby, add a fixture credential, configure seats and save own prompts.
The real API-key input is deliberately disabled.

## Security / deployment admission
Development backend is a single isolated fixture session, **NOT** an internet
account system. Do not expose dev/run.sh or its bootstrap. No real API key,
registration password or live vendor traffic is accepted. The production host
must use the existing owned ooRexx HTTPS listener, separate public game realm
with verified identity/session binding (LDAP/access permissions as appropriate),
CSRF/origin/TLS rules, server-created per-session Wire queues and explicit app
authorization. No private NOC/Office permissions are inherited. Real API keys
must enter through an authenticated, dedicated secret inlet and be stored in
the host-admitted encrypted credential provider with an opaque reference through existing Secret Broker v0.2 (reference/lease governance only, not a storage vault), never in
Wire actions, queue payloads, prompts, journal, browser storage or logs.
Use estate Anthropic v0.5 native Messages client and OpenAI-compatible v0.6 native client/approved engine adapters, with exact model profile admission, not browser fetch. Verify provider/model and key scope in the trusted broker; serve no real keys
back. Persist identities, membership, sealed profiles and game metadata in
estate durable storage before any accepted game launch. The game cannot start
before all seats/prompts and approved runtime/worker are admitted.
Bind task broker to frozen roster and engine's detached view; actual human
and model workers return raw response contract, not adjudication. Add true
deadline, phase/round barrier and idempotent recovery; dev6 controller is
qualified but live model and prompt evolution are separate engine work.
For mixed/human games even the lobby creator cannot read opponent press or
instructions; an account with a seat may never be a privileged reviewer in
that game. Prevent privileged review via alternate sessions; account identity
and scope are resolved server-side. Prevent collusion through separate
orchestrator accounts as an operational competition concern; software cannot
guarantee a person never shares what they know outside the platform.
Production reviewer must project only the authorized game, not raw logs.
Prompt experiment default lab reviewer may review delivered press, not raw
private reasoning. Additional replay/revision archive features await integration.

## Qualification
Local native gate: tests/run.sh (estate crypto at REXX_PATH).
The official runner additionally checks pinned dev6 source bytes against manifest.
Real Wire fixture: tests/wire.mjs against dev/run.sh URL. Browser suite
tests/browser.mjs requires working Chromium and Playwright. Browser binary
was missing in this workspace; visual DOM qualification remains NOT_RUN.
The fixture is not an approved deployment, and no DNS or TLS changes made.

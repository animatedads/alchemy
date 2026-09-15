# ooRexx Terminal Machine v0.21

Executable terminal-neutral automation infrastructure with a native IBM 5250/TN5250 vertical slice, read-only WatchAlong, replay/known-state memory, persistent one-session ownership, a bounded multi-client service broker, authenticated local IPC, operational health/readiness supervision, graceful multi-client service drain, journal-pointed emulator/testbed recovery, retained-branch time-travel inspection, exact-token speculative execution boundaries, checkpoint-bound instruction/event orchestration with linked retry history, and a credential-capability boundary for locally brokered sign-on/password recovery and trusted orderly IBM i signoff.


## v0.21 checkpoint-bound instruction/event orchestration

v0.21 turns the v0.20 exact-token execution primitive into a reusable emulator loop boundary. Emulator code no longer has to hand-code `begin()` / `commit()` / `rollback()` around every instruction or device event, and handler objects never receive the exact completion ticket.

```text
                 TerminalEmulatorEventOrchestrator
                              |
                    exact ticket retained here
                              |
                       pointer checkpoint
                              |
             +----------------+----------------+
             |                                 |
        instruction                       device/event
             |                                 |
          FETCH                              HANDLE
             |                                 |
          DECODE                               |
             |                                 |
         EXECUTE                               |
             +----------------+----------------+
                              |
                    success -> COMMIT
                    failure -> ROLLBACK
                              |
                     immutable history
                              |
                  optional linked RETRY
```

`TerminalEmulatorInstructionPipeline` is an explicit marker mixin with three fixed entry points: `emulatorFetch(event, context)`, `emulatorDecode(event, fetched, context)` and `emulatorExecute(event, decoded, context)`. `TerminalEmulatorEventHandler` is the equivalent marker for one-phase non-instruction events through `emulatorHandleEvent(event, context)`. The orchestrator deliberately does not accept arbitrary method names from callers.

Every accepted event is checkpointed before a handler runs. Plain return values are treated as success; an explicit failed `TerminalResult` or a trapped ooRexx `SYNTAX` causes exact rollback of all registered journal components. The handler receives a detached `TerminalEmulatorEvent` value object, not the state machine, execution boundary, checkpoint object or `TerminalEmulatorExecutionTicket`.

`retryInstruction()` and `retryEvent()` accept only retained attempts whose outcome is `ROLLED_BACK`. A retry gets a new event id and checkpoint but links to the failed attempt by `retryOfEventId`. This preserves the old failed journal future for debugger comparison while making the repaired forward execution explicit rather than silently overwriting history. Committed attempts are not legal retry sources.

`TerminalEmulatorEventHistoryEntry` is value-free operational/debugger evidence: event identity, kind/name, attempt number, retry linkage, checkpoint id, outcome, terminal phase, bounded fault code/detail, progress marker and phase status strings. It does not retain fetched instructions, decoded objects, execute return values, handlers, context objects, tickets or journal/state-machine references. History is bounded and caller-facing arrays/phase lists are detached projections.

The existing v0.19/v0.20 safety boundary remains absolute: this orchestration API is for `EMULATOR`, `TESTBED` and `REPLAY_SANDBOX` state only. It is not a scheduler for a real TN5250 host, cannot rewind IBM i, does not bypass terminal ownership/WLU admission, and does not widen credential/NONDISPLAY/raw-wire access. Explicit code repair remains the separate `TerminalEmulatorRecoveryCoordinator` path.

`examples/emulator_instruction_orchestration.rex` demonstrates a missing opcode that mutates speculatively, is automatically rolled back, is then repaired, and succeeds through a linked retry while the original failed checkpoint remains retained.

Semantic Source Control v0.2.2 was dogfooded before sealing this release. Its complete supplied r13196 suite passes, including the exact Terminal Machine reproducer that originally exposed `::constant` and `::attribute` as invisible semantic surfaces. v0.2.2 now reports `CONSTANT_VALUE_CHANGED` and `ATTRIBUTE_ACCESS_CHANGED`, tracks explicit accessor-body implementation changes, and batches SHA-256 entity hashing. A 30-file production-source baseline containing 851 methods, 522 attributes and 196 constants completed in 23.16 seconds on the debug runtime. A subsequent full production-source `scan` of v0.21 still failed to finish inside a 360-second certification window, so SSC remains supplementary release evidence rather than the sole release gate until that second-pass scaling path is repaired.

The package now carries an authoritative `SSC_MANIFEST` with `component=TerminalMachine`, `lineage=MAIN`, `sourceLevel=1`. The source level is deliberately **not** inferred from the v0.21 release number; it starts an explicit semantic-source lineage for future intake/impact decisions.


## v0.20 emulator time-travel inspection and speculative execution boundaries

v0.20 deepens the v0.19 Journal Pointed State integration for emulator/testbed use without widening any live-host authority. It adds a read-only retained-branch debugger surface plus an exact-token execution boundary for the common emulator discipline of checkpointing immediately before a speculative instruction/event.

```text
       retained journal graph
              /      \
       failed future  repaired future
              \      /
          common checkpoint
                 |
       TerminalEmulatorTimeline
          /       |        \
  checkpoint   branch      materialise
   evidence   topology      explicit values

instruction/event execution:

      begin(event)
          |
   pointer-only checkpoint
          |
  speculative state changes
       /         \
    commit      rollback
      |            |
 keep head     restore exact
               checkpoint
```

New v0.20 surfaces in `TerminalEmulatorJournal.cls` are:

- `TerminalEmulatorTimeline` — a **read-only** local debugger facade over retained checkpoints. It can resolve checkpoint evidence, compare two retained branches structurally, and explicitly materialise component state at an old checkpoint without moving any current journal head;
- `TerminalEmulatorCheckpointEvidence` — detached checkpoint identity/label/event/point evidence. Checkpoint metadata is scalar-sanitised: string values survive, object-valued metadata is represented as `<OBJECT>` rather than exporting the referenced object;
- `TerminalEmulatorBranchEvidence` — value-free branch topology containing per-component from/to journal points, undo/redo node ids, tags, timestamps and changed keys. It deliberately omits old/new state values and returns deep copied plan structures so caller mutation cannot rewrite retained evidence;
- `TerminalEmulatorExecutionBoundary` and immutable `TerminalEmulatorExecutionTicket` — enforce one active speculative attempt, automatically checkpoint before execution, require the **exact issued ticket object** for commit/rollback, reject forged/lookalike/stale tickets, and restore all registered components on rollback;
- `TerminalEmulatorStateMachine~checkpointById()`, `materialiseCheckpoint()` and `timeline()` — explicit local debugger helpers above the same external `StateOfNationController`.

The execution boundary does not install code or silently repair a fault. It is deliberately orthogonal to `TerminalEmulatorRecoveryCoordinator`: the boundary establishes exact pre-event state and completion authority; the recovery coordinator remains the explicit code-forward/state-backward live-method repair path for objects inheriting `TerminalEmulatorPatchable`.

`materialiseCheckpoint()` is intentionally marked SENSITIVE/INTERNAL because it returns value-bearing emulator state. It does not claim deep serialisation: Journal Pointed State's immutable/copy-on-write value ownership rule still applies. `TerminalEmulatorTimeline~branch()` is the safe structural inspection path when actual historical state values are unnecessary.

`examples/emulator_time_travel_debugger.rex` demonstrates a failed future and a repaired fork: the first attempt advances PC, rolls back to its exact ticket checkpoint, a second attempt commits a different future, and the abandoned branch remains structurally comparable and value-materialisable without moving the live head.

The v0.19 safety boundary remains absolute. `LIVE_HOST` still cannot be constructed; none of these classes are authority to rewind a real TN5250 host, modify `TerminalSessionOwner`, bypass WLU admission, expose NONDISPLAY contents, or install methods on terminal/broker/service objects.

Fresh-extraction v0.20 acceptance is 101/101 manifest entries, 91/91 core/test/tool `rexxc` targets, 2/2 example compilations, 44/44 self-contained functional cases, the retained 15-assertion authenticated socket suite, persistent multi-client and operational-supervisor service suites, external WLU v0.12 integration, TCP loopback, verified TLS loopback and forced stuck-helper TERM→KILL cleanup. No PUB400 login was performed.


## v0.19 journal-pointed emulator/testbed state and live repair

v0.19 inserts the user-supplied **ooRexx Journal Pointed State v0.1** architecture into Terminal Machine as an **external emulator/testbed state primitive**, not as a live-host rewind mechanism. The package remains external (SHA-256 `8466bc2309213f3acc2de2afb6b2596123e446d779ca90c319aed676544c51d8`) and is loaded through `JOURNAL_POINTED_STATE_SRC`.

The key property is that an emulator checkpoint is a set of journal pointers rather than a deep copy of the whole machine. Multiple components can therefore be checkpointed together immediately before an instruction/event, mutated speculatively, and restored together. If execution is repaired and retried, the failed future remains retained as a branch and can still be reconstructed.

```text
        TerminalEmulatorStateMachine
                    |
        StateOfNationController
          /        |         \
   CPU registers  memory    device state
      journal      journal      journal
          \        |         /
           pointer-only checkpoint
                    |
             speculative event
                    |
               fault / stall
                    |
      explicitly marked emulator patch
                    |
             restore checkpoint
                    |
              retry same event

         code moves forward
         state may move backward
```

New `TerminalEmulatorJournal.cls` provides:

- `TerminalJournalComponent` — a named wrapper around one `JournalPointedState`, with batched edits, branching reconstruction/diff and the State-of-the-Nation participant contract;
- `TerminalEmulatorStateMachine` — coordinates pointer-only checkpoints and all-or-nothing preflighted restore across registered components, exposes pointer-only `stateOfNation()` evidence, retained checkpoint indexing and `StateProgressWatcher` creation;
- `TerminalEmulatorPatchable` — an explicit opt-in marker for live method repair;
- `TerminalEmulatorRecoveryCoordinator` — front-end-driven code-forward/state-backward repair which revalidates both the original and any response-overridden target before installing source, then restores the armed checkpoint.

The live-patch boundary is deliberately narrower than the generic Journal Pointed State example. Merely having `setMethod()` or an `installLiveMethod()`-shaped method is **not** enough. A target must explicitly inherit `TerminalEmulatorPatchable`. This prevents the journal repair mechanism from becoming accidental authority to modify `TN5250LiveSession`, `TerminalSessionOwner`, transports, brokers or other live terminal/service objects. `LIVE_HOST` mode is rejected at construction; allowed modes are `EMULATOR`, `TESTBED` and `REPLAY_SANDBOX`.

The companion Queue Fabric live-patch demo supplied with Journal Pointed State was also reviewed. Its two-process permanent-queue pattern is useful as a **transport example**: method source can be carried as an ooRexx object graph to a running emulator, while the receiver performs the actual patch and rewind. Queue Fabric is intentionally **not** pulled into Terminal Machine core by v0.19; patch delivery remains pluggable, so a queue, broker, rule engine, human front end or AI-backed front end can all feed the same explicit emulator recovery boundary.

`examples/emulator_journal_repair.rex` demonstrates the missing-opcode loop: checkpoint at PC 4096, speculative advance, install `OPCAFE`, restore the machine pointer, then retry successfully without restarting the emulator.

The journal value rule is inherited unchanged: values stored in journal state should be immutable values or copy-on-write/replacement objects. The journal records references, not deep serialised object copies. Durable/exportable emulator freeze formats remain a separate boundary; this facility is an in-process execution/history primitive.

The existing Terminal Machine secret and real-host rules remain unchanged. In particular, this new facility does **not** claim that rewinding a local terminal model rewinds a remote IBM i host, and it is not used for live TN5250 ownership, credential state, raw wire data or WLU authority.

## v0.18 service operation and health supervision

v0.18 adds an operational layer above the v0.17 persistent service lifecycle. The new `TerminalBrokerServiceSupervisor` does **not** own sockets, protocol bearers, broker client/controller capabilities, the `TerminalSessionOwner`, the live TN5250 runtime or WLU reservations. It owns only the service-lifecycle coordinator as a private capability and publishes detached scalar health evidence.

```text
                 one retained terminal session
                           |
                  TerminalSessionOwner
                           |
                  TerminalSessionBroker
                           |
             TerminalBrokerProtocolEndpoint
                           |
              TerminalBrokerLocalSocketHost
                           |
             TerminalBrokerServiceLifecycle
                           |
             TerminalBrokerServiceSupervisor
                 /         |          \
             health       start      shutdown
            (read)      (controlled)  (drain)
```

`health()` deliberately cross-checks the layers instead of trusting one status bit. A service is `HEALTHY`/ready only when the lifecycle is `RUNNING`, the socket service is `RUNNING`, the actual listener is `LISTENING`, the private acceptor activity is live, the bound port and worker limit are valid, the serialized endpoint is `OPEN`, and the retained broker/session is `OPEN`. If the lifecycle claims `RUNNING` while any of those boundaries disagrees, health is `DEGRADED` and `requireReady()` fails closed.

The detached `TerminalBrokerOperationalHealth` surface carries only scalar/value evidence: lifecycle/socket/listener/protocol/broker states, bound port, service generation, worker limit, acceptor state, connection counters, request/rejection/authentication counts, broker client/controller counts, drain reason and bounded error text. Live host/endpoint/broker/lifecycle references remain absent from Alchemy FULL state. A historical non-fatal socket error is exposed separately as `socketLastError`; it is not silently promoted to lifecycle failure or used as authority.

Controlled operation remains intentionally asymmetric:

```text
start
  -> lifecycle launch
  -> require all readiness boundaries

shutdown
  -> socket drain
  -> finish accepted workers
  -> protocol quiesce
  -> terminal/broker remains owned and OPEN

optional IBM i signoff
  -> separate protected call
  -> exact IBM_I_MAIN_MENU + external admission
  -> 90 + exactly one ENTER
  -> observation only until confirmed remote close
```

There is still no remote "shutdown the terminal" verb hidden inside the client protocol. Ordinary authenticated clients cannot convert service health or service drain into terminal close/signoff authority. This keeps service administration separate from terminal mutation and preserves the v0.17 fail-closed signoff rules.

`TerminalBrokerServiceStatus` was expanded compatibly to carry detached socket-service generation/worker/acceptor/counter evidence plus broker client/control evidence. Older/lightweight host fixtures still work because optional status fields are copied only when supported.

New acceptance includes `test_terminal_broker_operations.rex` and `test_terminal_broker_operations_service.sh`. The latter drives the real first-party ooRexx socket service through the supervisor with two independently HMAC-authenticated client processes simultaneously resident (`peak=2`), confirms `HEALTHY` readiness before drain, then confirms `QUIESCED` lifecycle/protocol state with the listener stopped while the terminal broker remains `OPEN` and unclosed.

Fresh-extraction v0.18 acceptance is 94/94 manifest entries, 86/86 `rexxc` targets, 40/40 self-contained functional cases, the retained 15-assertion authenticated socket suite, both persistent multi-client socket suites, external WLU v0.12 integration, TCP loopback, verified TLS loopback and forced stuck-helper TERM→KILL cleanup. No PUB400 login was performed.

The updated `oorexxapis(20260825-083438).zip` roll-up resolves the retained Terminal Machine dependency closure to Alchemy Objects v0.8, ooRexx Crypto v0.1 and WLU v0.12; v0.19 additionally requires the user-supplied external ooRexx Journal Pointed State v0.1 source root for emulator-journal functionality. Duplicate same-version deliveries elsewhere in the roll-up are treated by SHA/content/lineage rather than filename suffix ordering; Terminal Machine v0.17 in that roll-up matches the accepted v0.17 parent SHA exactly.

## v0.17 persistent multi-client service hosting

v0.17 turns the v0.16 authenticated loopback adapter into a long-lived service host without moving terminal ownership into the socket layer. One acceptor owns the blocking `accept()` call and dispatches accepted connections to a bounded set of ooRexx activities. The terminal itself still has exactly one `TerminalSessionOwner`; concurrent socket clients only carry authenticated protocol capabilities.

```text
                     one TN5250LiveSession
                              |
                    TerminalSessionOwner
                              |
                    TerminalSessionBroker
                              |
                TerminalBrokerProtocolEndpoint
                              |
                 TerminalBrokerLocalSocketHost
                    /          |          \
              client A     client B     client C
             observer      controller    observer
                         (one writer only)
```

`launchService(maxConnections, backlog)` starts one private acceptor activity and bounded per-connection workers. `serveOne()` cannot steal the listener while the persistent service is active, and trust bindings are immutable while the service is `RUNNING` or `DRAINING`. Active/peak/completed connection counts are scalar evidence only; worker/socket/peer/endpoint authority objects are never Alchemy registered state. Unexpected endpoint `SYNTAX` failures are contained to the affected worker, its socket is closed, active-worker accounting is completed, and the service remains drainable.

Graceful shutdown is deliberately ordered rather than equivalent to `close()`:

```text
request socket drain
      -> stop admitting new connections
      -> let existing bounded workers finish
      -> quiesce serialized protocol capabilities
      -> terminal remains retained
      -> optional trusted IBM i signoff
```

`TerminalBrokerProtocolEndpoint~quiesce()` revokes endpoint-local client/controller bearers, admission handles and replay state without closing the broker or terminal. If a broker-side detach fails, endpoint-local bearer authority is still removed, the endpoint becomes `QUIESCE_FAILED`, and later remote requests fail closed. `TerminalBrokerServiceLifecycle` coordinates socket drain before protocol quiesce and will not silently restart a quiesced service.

The optional trusted IBM i shutdown path is `TerminalBrokerServiceLifecycle~orderlyIBMISignoff()`. It is permitted only after service quiesce, requires zero attached remote clients/controllers, requires a real external admission/WLU reservation, and must uniquely match `IBM_I_MAIN_MENU`. It then acquires ordinary broker control, stages literal option `90`, sends exactly one `ENTER`, releases control, and sends no further input. Only confirmed remote close completes signoff and permits final broker close. A changed screen, pump error, ENTER failure or timeout is **not** converted into a generic disconnect: the broker remains open and quiesced for trusted diagnosis/known-state learning.

The acceptor drain uses a loopback wake connection because that is the portable pattern supported by the supplied r13196 RxSock implementation. The listener remains fixed to `127.0.0.1`; v0.17 still provides authentication and integrity rather than confidentiality. Existing v0.15 NONDISPLAY denial/redaction and raw-wire secrecy remain unchanged.

New regressions include `test_terminal_broker_service.rex`, `test_broker_orderly_signoff.rex`, and `test_terminal_broker_socket_service.sh`. The cross-process service fixture proves two independently authenticated clients are simultaneously resident (`peak=2`) before drain. Socket unit acceptance also injects an endpoint exception and proves it cannot strand active-worker accounting or prevent drain.

The current `oorexxapis(20260824-191006).zip` baseline resolves to external Alchemy Objects v0.8, ooRexx Crypto v0.1 and WLU v0.12. Queue Fabric v0.9-dev4 and Secret Broker v0.2 remain reviewed sibling facilities, not hidden Terminal Machine dependencies.

## v0.16 authenticated local IPC adapter

v0.16 gives the v0.15 serialized endpoint a real local inter-process transport without moving terminal ownership into the socket layer. The process which owns `TerminalSessionOwner` can now retain the one live terminal session while local clients connect through a bounded authenticated adapter:

```text
local client process
      |
      | terminal.broker.socket/0.1
      | HMAC + nonces + sequence
      v
TerminalBrokerLocalSocketHost
      |
      | authenticated principal + v0.15 broker frame
      v
TerminalBrokerProtocolEndpoint
      |
TerminalSessionBroker
      |
TerminalSessionOwner
      |
 one live terminal session
```

The supplied ooRexx r13196 socket class exposes AF_INET rather than AF_UNIX. v0.16 therefore does **not** claim to implement a Unix-domain socket and does not introduce a helper process merely to imitate one. The listener is fixed to `127.0.0.1`, verifies the accepted peer address again, and uses the official ooRexx `Socket` / `StreamSocket` objects.

Local transport authentication is explicit. A host administrator injects a principal + key-id + HMAC key binding with `trustPrincipal()`; there is no default key. Each connection uses independent 256-bit client and server nonces. HELLO, CHALLENGE, every broker REQUEST/RESPONSE, and BYE/BYE_ACK are HMAC-SHA-512 authenticated. Sequence numbers are strictly increasing, so same-connection replay is rejected. The principal established by that exchange is passed as a separate argument to the v0.15 endpoint; a `principal` field inside broker JSON has no authority.

The HMAC key, peer table, nonces, listener/connection objects, framer and transport authority are not Alchemy registered state. FULL introspection retains only scalar operational evidence such as loopback host, port, lifecycle state, request counts and the bounded I/O timeout. This extends the v0.13 rule that introspection cannot become a capability-transfer mechanism.

The socket adapter is intentionally bounded: 262,144-byte records by default, 256 authenticated broker requests per connection by default, and a 30,000 ms socket I/O inactivity timeout. The latter is expressed in milliseconds because that is the r13196 RxSock `SO_RCVTIMEO` / `SO_SNDTIMEO` contract. v0.16 services one accepted connection synchronously through `serveOne()`; the timeout and request budget prevent an idle connection from becoming unbounded ownership of that service path. Parallel worker dispatch remains a separate future service-host concern.

This is an authentication/integrity layer, **not transport confidentiality**. That distinction is deliberate rather than hidden. The v0.15 protocol still masks NONDISPLAY snapshot data, forbids remote secret-field input before mutation, keeps raw TN5250 READ-response bytes below the owner boundary, and keeps WLU/admission objects inside the trusted endpoint process. A future AF_UNIX or TLS transport can implement the same endpoint contract without modifying terminal semantics.

`test_terminal_broker_socket.rex` verifies the Alchemy/reference and canonical-authentication surfaces. `test_terminal_broker_socket.sh` drives real cross-process ooRexx sockets and checks a successful multi-request authenticated session, request-body principal spoof resistance, wrong-key rejection, forged request-MAC rejection, forged server challenge rejection, forged response-MAC rejection, and proof that socket host shutdown never closes the endpoint.

The current `oorexxapis(20260824-191006).zip` roll-up was resolved by component identity/content rather than filename ordering. v0.16 acceptance uses external Alchemy Objects v0.8, ooRexx Crypto v0.1 and WLU v0.12. The same roll-up also contains Queue Fabric v0.9-dev4 and Secret Broker v0.2; both were reviewed as sibling facilities but are not silently imported. Queue delivery semantics, provider-secret leasing and terminal ownership remain separate components.

## v0.15 serialized broker protocol / IPC boundary

v0.15 puts a serialization and authority boundary around the v0.14 persistent `TerminalSessionBroker` without turning the terminal package into a socket daemon. `TerminalBrokerProtocolEndpoint` accepts already-authenticated principal identity from a trusted surrounding transport and processes bounded JSON messages; the request body cannot assert or replace that principal.

```text
trusted local/service transport
        |
        | authenticated principal
        v
TerminalBrokerProtocolEndpoint
        |
        | opaque bearer capabilities
        v
TerminalSessionBroker
        |
TerminalSessionOwner
        |
 one live terminal session
```

Frames use an exact eight-ASCII-hex-digit payload length followed by one JSON payload. Oversize, incomplete, invalid-header and trailing-data frames fail closed. The endpoint is deliberately transport-neutral: Unix-domain socket, pipe, message fabric or another authenticated local/service transport can host it later without moving terminal ownership semantics into the IPC adapter.

Remote authority is explicit and bounded:

```text
observation = authenticated principal + opaque client token
mutation    = authenticated principal + opaque controller token
admission   = host-registered opaque handle -> real external WLU reservation
```

There is no built-in fallback token generator. The host must supply a token source implementing `issueToken(purpose, principal, bindingId)`, and issued bearer values are checked for minimum/maximum size and active-token collision. Real `TerminalBrokerClient`, `TerminalBrokerController`, WLU/admission reservations, owner/session objects and transport/runtime objects remain inside the trusted endpoint process and are never serialized.

Controller handoff preserves the one-writer rule and also prevents authority disclosure. The old controller can request handoff, but its response does **not** contain the new controller token. After release -> no-controller -> target acquisition, the target authenticated principal retrieves its own token using its own client bearer through `CONTROL_STATUS`. No action/keystroke queue is introduced.

Snapshot output is an allow-list projection rather than arbitrary object serialization. NONDISPLAY field values are always emitted as `<SECRET>`, and presentation cells covered by NONDISPLAY fields are defensively re-masked even if an upstream fixture supplies plaintext. Remote `SET_FIELD` and cursor-relative `TYPE_AT_CURSOR` into a NONDISPLAY field are rejected before terminal mutation; password/current-new-verify staging remains a trusted local credential operation. AID/System Request paths remain owner-mediated, so raw TN5250 READ-response bytes cannot cross the safe broker protocol.

The protocol has bounded request-id replay/idempotency. Replay memory stores only authenticated principal, request id, operation and the encoded response; it never retains the serialized request body or rejected secret-bearing input. Reusing one request id for a different operation is rejected.

For current v0.17 acceptance, the inherited Alchemy integration is advanced to `alchemy_objects_v0.8`. `TerminalAlchemyObject` enters the base through the preferred `self~init:super(...)` construction path and supplies STANDARD-adoption metadata for Terminal Machine stateful objects. The v0.13 reference rule remains absolute: Alchemy registered state contains scalar/value evidence only, never broker/token maps, replay entries, live capabilities, reservations, runtime/transport objects, sealers or capability authorities.

`test_terminal_broker_protocol.rex` exercises framing, principal/token binding, admission handles, one-writer acquisition/handoff, secret-safe projections, pre-mutation NONDISPLAY denial, replay safety and FULL-introspection reference boundaries. `test_alchemy_base_integration.rex` additionally verifies v0.8 STANDARD adoption, INIT construction provenance and absence of the legacy-init warning.

## v0.14 persistent session broker / service core

v0.14 adds the service boundary above the v0.12/v0.13 ownership layer. The process which owns the real terminal retains the `TerminalSessionOwner`; AI/operator participants are issued only broker-side capabilities:

```text
TN5250LiveSession
       |
TerminalSessionOwner
       |
TerminalSessionBroker
   /       |       \
client   controller  client
(read)   (one writer) (read)
```

The broker deliberately does **not** hand a client the `TerminalSessionOwner`, owner-side `TerminalAttachedObserver`, owner-side `TerminalAttachedController`, live TN5250 session, runtime, transport, WLU/admission reservation, or secret-capable wire output. `TerminalBrokerClient` is read-only until it presents an external admission proof through `requestControl()`. `TerminalBrokerController` then proxies only the bounded controller operations already enforced by the owner/control gate.

The two capability layers use exact issued-object identity. Copying a `clientId`, principal, `leaseId`, or other opaque text does not reproduce authority. A controller handoff remains:

```text
release old owner-side controller
        ->
prove NO CONTROLLER
        ->
acquire target observer at current generation
        ->
issue new broker controller
```

No action queue is introduced, so stale keystrokes cannot accumulate while control is transferred. Detaching the controlling broker client revokes owner-side control before the client capability becomes inactive.

`TerminalBrokerStatus` is a detached value object containing only scalar service evidence: broker/session id, lifecycle state, client count/capacity and current controller/opaque lease identity. It carries no service authority.

The v0.13 Alchemy rule is preserved at the new layer: registered state is scalar/value evidence only. The exact broker back-reference inside client/controller facades, the retained owner, owner-side observer/controller objects, client tables and key/sealer/capability-authority objects are all unregistered. A dedicated FULL-introspection regression proves those objects cannot be re-exported through Alchemy state.

v0.14 is intentionally a **service core, not an invented IPC protocol**. It is suitable for hosting behind a local socket, message transport or other process boundary later, while keeping terminal policy independent of the chosen IPC mechanism. The important architectural boundary now exists: a service process can retain the only real owner while clients operate through bounded capabilities.

The generic `TerminalSessionBroker~close()` remains transport/session teardown, not host signoff authority. IBM i orderly signoff still requires an exact known-state match and the existing explicit MAIN-menu `90` staging + ENTER path before service teardown.

## v0.13 Alchemy introspection authority-reference hardening

v0.13 closes a capability leak in the way Terminal Machine v0.10-v0.12 used Alchemy registered state. `alchemy_objects_v0.4.3` treats disclosure labels as **visibility policy**; it does not automatically detach or stringify an object variable. Under an explicitly authorized `FULL` introspection profile, a registered object variable is emitted as the exact ooRexx object reference. A regression probe against the v0.12 parent proved this directly: `TerminalAttachedObserver`'s registered `owner` entry was identity-equal to the live `TerminalSessionOwner`.

That is unacceptable for a terminal capability boundary. An introspection result may describe authority; it must not **become** authority. Terminal Machine therefore now applies the stronger rule:

```text
Alchemy registered state = scalar/value evidence only

never register as state:
    live session / runtime / transport
    owner / observer / controller capability objects
    control leases or admission reservations
    cryptographic sealer/capability-authority objects
    mutable tables/arrays used as internal state
```

The private ownership token was already deliberately omitted from `TerminalSessionOwner` in v0.12, but that was not sufficient: the same token was held by `TN5250LiveSession~ownershipOwner`, which had been registered as `SECRET`; attached observers/controllers also registered their trusted `owner` back-reference. Because `FULL` includes `SECRET`, those registrations could re-export exact authority objects to a sufficiently privileged introspection caller. v0.13 removes every such registered reference.

Customer-facing scalar evidence remains unchanged: session identity/lifecycle, generation, bounded counts, semantic state ids, controller identity/opaque lease id, device evidence and similar values remain available. Internal collections continue to be accessed only through the terminal's explicit detached/copy-safe methods. The Alchemy relationship/instrumentation mechanisms remain appropriate for describing object relationships because they record identifiers/evidence rather than retaining a returned authority reference.

`test_alchemy_reference_boundary.rex` performs `FULL` introspection with non-nil live authority objects in place and proves that the state payload contains no owner, runtime, transport, reservation, lease, mutable collection, sealer or capability-authority object reference. This is a disclosure-boundary hardening cut; it does not alter TN5250 wire behavior, PUB400 state sequencing, WLU admission or one-writer/many-reader control semantics.

## v0.12 persistent interactive session ownership

v0.12 adds the process-resident ownership layer required to keep **one real terminal connection** alive while several AI/operator participants observe it. `TerminalSessionOwner` creates an unexported exact-object ownership capability, claims an already-constructed live session with that private token, owns its lifecycle/pump/control paths, and issues only bounded attached capabilities:

```text
                   TerminalSessionOwner
                           |
                    ONE live session
                           |
             +-------------+-------------+
             |             |             |
     AttachedObserver  AttachedController  AttachedObserver
          AI-A             AI-B               AI-C
          READ             WRITE              READ
```

Attaching another observer does not call `open()`, create another TLS helper, negotiate another DEVNAME, or create another IBM i display. The owner caches one read-only observation surface and all observers see detached evidence from that same live generation. `TerminalAttachedObserver` has no field/AID/System Request mutation methods and does not expose the owner object.

The underlying `TN5250LiveSession` now supports exact-object `claimExclusiveOwner()` / `releaseExclusiveOwner()` capability checks. `TerminalSessionOwner` supplies an unexported private token for that claim; the owner facade itself is deliberately **not** the token. Once claimed, retained references to the raw live-session object cannot bypass the owner: `open`, semantic tracker attachment, gate enable/acquire/revoke, network pumping, trusted terminal-output flushing and `close` all require that exact private capability. A second claim receives `SESSION_OWNERSHIP_BUSY`. The claim is released only after the live session reaches `CLOSED` and no controller remains active.

Keyboard authority remains **one writer / many readers**. Control can be requested only by an issued observer attachment. `TerminalAttachedController` wraps the existing `TerminalLeasedController` but never returns the raw lease/controller capability. Handoff is deliberately:

```text
release old controller
        |
        v
NO CONTROLLER
        |
        v
acquire target observer at current generation
```

There is no queued keystroke layer, so a handoff cannot inherit stale input. Exact issued observer/controller object identity is checked instead of trusting attachment-id text. Detaching the observer which currently owns the keyboard revokes control before invalidating the attachment.

TN5250 AID/System Request wire output is also kept inside the trusted owner. The attached controller receives only the safe action result; successful actions are followed by owner-mediated `flushTerminalOutput()`, whose raw bytes may contain NONDISPLAY field data and therefore never cross the safe automation boundary.

The ownership objects use the Alchemy base rather than inventing a parallel service framework:

```text
AlchemyObject
    |
TerminalAlchemyObject
    |
    +-- TerminalSessionOwner
    +-- TerminalAttachedObserver
    `-- TerminalAttachedController
```

CUSTOMER introspection may report session id, observer count, current controller identity/lease id and lifecycle state. **Historical v0.12 note:** this cut originally described live references as protected by INTERNAL/SECRET disclosure. v0.13 demonstrated that `FULL` includes those labels and emits registered values by exact reference, so v0.13 supersedes that assumption: live/authority references are now unregistered entirely. The private ownership token had already been omitted from the owner state, but v0.13 also removes every alternate registered route to it.

This ownership cut is intentionally process-resident. v0.14 now layers `TerminalSessionBroker` above it as the bounded service core; v0.14 still does not invent a daemon or cross-process wire protocol. The service process retains the owner object while the session is in service.

`TerminalSessionOwner~close()` is generic transport/session teardown, **not an IBM i signoff shortcut**. A host-specific orderly signoff must still be performed through a controller after an exact known-state match (for PUB400, the confirmed `IBM_I_MAIN_MENU` -> stage `90` -> explicit ENTER flow) before the generic owner is closed. This keeps host policy out of the terminal-neutral ownership layer.

## v0.11 live semantic state tracking + host-assigned device identity

v0.11 turns the known-state catalogue from a manually queried library into an optional read-only live watcher. `TerminalKnownStateTracker` consumes committed detached snapshots, records `MATCH` / `NO_MATCH` / `AMBIGUOUS`, exposes the unique current state id and generation, keeps bounded detached semantic history, and counts distinct known-state transitions. It remains deliberately incapable of terminal mutation: observed state and observed transitions are still knowledge, never action authority.

A `TN5250RuntimeSession` can now `attachKnownStateCatalog()`. Its `TN5250ObservationSession` then exposes only semantic read methods (`knownStateStatus`, `knownStateId`, `knownStateGeneration`, `knownStateHistory`) in addition to the existing redacted snapshot/history surface. `TN5250LiveSession` mirrors the current semantic status/id/generation into its Alchemy CUSTOMER disclosure while retaining the catalogue/tracker itself as INTERNAL.

The second live fix comes directly from PUB400. When no DEVNAME is requested, IBM i may allocate a display such as `QPADEV0012` without NEW-ENVIRON giving the client that allocation as a negotiation fact. `TN5250DeviceIdentity` therefore preserves three separate evidence channels:

```text
requested DEVNAME       -> REQUESTED_DEVNAME
client-selected DEVNAME -> TELNET_DEVNAME
host sign-on display    -> HOST_SIGNON_SCREEN
```

The confirmed IBM i sign-on panel's `Display name` value is now captured as `assignedDeviceName`. It becomes the effective active device identity while remaining explicitly labelled as screen evidence rather than being falsely described as Telnet negotiation. If both screen and negotiated identities exist and disagree, both are retained and the identity is marked inconsistent.

This matters operationally for leaked/disconnected sessions: a server-assigned QPADEV can now be named in diagnostics instead of appearing as a blank `NEGOTIATED_DEVICE=`. If the live session learns the host display before the exclusive control gate is enabled, its default control scope uses the effective device identity.

`pub400_login_signoff_once.rex` and the password-recovery tools now report the host display device. The ordinary login/signoff tool also attaches the known-state tracker so a live run shows the semantic state independently of its explicit fail-closed checks. The final `90` signoff behavior is unchanged.

## v0.10 Alchemy Objects base integration

v0.10 adopts the supplied `alchemy_objects_v0.4.3` base infrastructure for the terminal's long-lived/stateful object surfaces while deliberately leaving detached immutable evidence/value objects plain. This preserves the invariant that observing a `TerminalSnapshot` cannot mutate it merely by incrementing inherited lifecycle telemetry.

The new `TerminalAlchemyObject` base sits between application terminal objects and `AlchemyObject`:

```text
AlchemyObject (alchemy_objects_v0.4.3)
        |
TerminalAlchemyObject
        |
        +-- TerminalTrace
        +-- TerminalReplay
        +-- TerminalWatchAlong
        +-- KnownStateCatalog
        +-- TerminalSession
        +-- TerminalControlGate
        +-- TN5250LiveSession
```

These objects now inherit Alchemy object identity, lifecycle/use telemetry, structured metadata, state-disclosure declarations, method contracts, instrumentation, requirement evidence, compliance surfaces and optional cryptographically sealed introspection. The terminal registers its own bounded instrumentation points for lifecycle, authority/control transitions and observations.

Secret boundaries are preserved in the inherited disclosure model. In particular, the trusted TN5250 runtime, Alchemy sealer/capability authority and active external admission reservation are registered as `SECRET`; WatchAlong history and trusted terminal models remain `INTERNAL`; ordinary session ids, lifecycle state and observed generation can be exposed at `CUSTOMER` profile. `PUBLIC` introspection still carries descriptions/contracts/telemetry but no registered state values.

The integration remains dependency-clean: Alchemy Objects, ooRexx Crypto and WLU are external and are not vendored into Terminal Machine. v0.10 originally integrated `alchemy_objects_v0.4.3`; current v0.19 acceptance uses `alchemy_objects_v0.8`, `oorexx_crypto_v0.1`, `oorexx_work_load_units_v0.12` and external `oorexx_journal_pointed_state_v0.1`. `run_tests.sh` requires explicit `ALCHEMY_OBJECTS_SRC`, `CRYPTO_SRC` and `JOURNAL_POINTED_STATE_SRC` roots, with `WLU_SRC` enabling the concrete external WLU regression, so stale classes elsewhere on `REXX_PATH` cannot silently win.

The Alchemy base is applied to stateful service/coordination objects, not every data carrier. `TerminalSnapshot`, field snapshots, actions, meter facts, leases and known-state evidence remain detached/value objects where adding mutable lifecycle counters would weaken their evidence semantics.

## Design boundary

The terminal core is deliberately not a `TN5250Session` abstraction.  The common layer remains terminal-family neutral:

```text
TerminalSession
TerminalCapabilities
TerminalSnapshot
TerminalAction
TerminalWatchAlong
TerminalTrace / TerminalReplay
FrozenTerminalState
KnownTerminalState / KnownStateCatalog

        |
        +-- FieldTerminalModel       (5250 now; 3270 later)
        +-- CharacterGridModel       (VT-family later)
        +-- StreamTerminalModel      (TTY/PDP-style console)
```

A common interface does not mean a lowest-common-denominator screen.  Field terminals retain fields and attributes; grid terminals retain cells/cursor semantics; stream terminals remain streams.

## v0.9.2 confirmed PUB400 password-expiry order and orderly signoff

v0.9.2 incorporates the confirmed live PUB400 recovery sequence as an explicit state policy rather than a permissive shortcut:

```text
IBM_I_SIGNON -- ENTER #1 --> IBM_I_PASSWORD_EXPIRED_NOTICE
IBM_I_PASSWORD_EXPIRED_NOTICE -- ENTER #2 --> IBM_I_CHANGE_PASSWORD
IBM_I_CHANGE_PASSWORD -- ENTER #3 --> IBM_I_MAIN_MENU
IBM_I_MAIN_MENU -- option 90 + ENTER #4 --> orderly signoff / remote close
```

`TN5250PasswordExpiryFlow` rejects a direct sign-on-to-change-password transition. `IBM_I_MAIN_MENU` is now a confirmed known state learned from the live PUB400 result screen. The one-shot recovery tool will stage menu option `90` only when that state uniquely matches and the host presents the expected command field at row 20, column 7. Any other post-change screen receives no input.

`TN5250Signoff~stage90()` stages only the non-secret `90` value and deliberately does not press Enter; the final signoff AID remains a separate explicit action. After ENTER #4 the tool waits only for remote close or the first changed screen, sends no further input, and then verifies TLS helper shutdown.

For ordinary post-recovery use, `tools/pub400_login_signoff_once.rex` performs a normal confirmed sign-on, requires `IBM_I_MAIN_MENU` as the first changed host screen, stages `90`, sends one signoff Enter, then waits for remote close/first changed screen and tears down TLS. It is the preferred one-shot live acceptance tool when the password is no longer expired.

## v0.9.1 TLS helper lifecycle hardening

v0.9.1 fixes a live-session resource leak discovered against PUB400: the external `socat` TLS helper could remain after the terminal tool had finished or been interrupted, leaving the IBM i side believing that a virtual display session was still connected.

`SocatTlsTerminalTransport` now captures and owns the exact helper PID, validates that the process still names this transport's unique loopback listener and TLS peer before signalling it, and treats shutdown as a confirmed lifecycle operation rather than a best-effort `kill`.  Close first drops the loopback socket, then performs TERM -> bounded wait -> KILL -> bounded wait if necessary.  A defunct/zombie helper is treated as stopped because it no longer owns network resources; PID reuse is never signalled blindly.

The transport also implements `UNINIT` cleanup, validates the TLS port before shell interpolation, and exposes the helper PID for trusted diagnostics.  `TN5250LiveSession~close()` now propagates TLS-helper shutdown failure instead of reporting `CLOSED` when the helper may still be alive.

All interactive PUB400 tools install a top-level HALT cleanup path, so Ctrl-C outside a hidden-password prompt closes the TLS transport before exit.  The TLS regression suite now proves both ordinary helper shutdown and forced escalation by SIGSTOP-ing the helper before close.

## v0.9 trusted password-change recovery

v0.9 completes the deliberately unfinished live IBM i expired-password path without weakening the observer/secret boundary.  The new `TN5250PasswordChange` layer consumes a short-lived trusted `TN5250PasswordChangeLease` only after the current snapshot uniquely matches `IBM_I_CHANGE_PASSWORD`.  `KnownState5250Factory~findChangePasswordFields()` returns the structured current/new/verify field mapping used by both state construction and credential staging.

The three password values are staged transactionally through a trusted runtime primitive which requires all target fields to be host-declared input-capable `NONDISPLAY` fields.  The new password is written to both the new and verification fields.  Safe snapshots expose only `<SECRET>`, traces record only `<SECRET>`, and the AI-facing `TN5250AutomationSession` has no method for the trusted triple-secret staging primitive.  A failed/overflowed triple rolls the presentation space back rather than leaving a partially modified password form.

Password staging and submission remain separate actions.  `TN5250PasswordChange~stage()` does **not** press Enter.

`tools/pub400_change_password_once.rex` is the bounded local-operator recovery path.  It:

1. requires the persisted live catalogue to contain `IBM_I_SIGNON`, `IBM_I_PASSWORD_EXPIRED_NOTICE`, `IBM_I_CHANGE_PASSWORD`, and `IBM_I_MAIN_MENU`;
2. waits for an exact `IBM_I_SIGNON` match before requesting the existing user profile/password;
3. submits sign-on once and follows only the confirmed expired-password continuation;
4. requests the new password and local verification only after an exact `IBM_I_CHANGE_PASSWORD` match;
5. stages current/new/verify transactionally into the three host NONDISPLAY fields;
6. sends one explicit password-change Enter;
7. requires the result to match `IBM_I_MAIN_MENU` before any further input;
8. stages menu option `90` and sends one explicit signoff Enter;
9. waits for remote close or the first changed screen, sends no further input, and closes the TLS helper.

Passwords are read from `/dev/tty` with echo disabled; none is accepted through argv or environment variables.  If a device name is supplied, the tool uses `STRICT` DEVNAME collision policy: exact device or abort, never silent substitution.

## v0.8 exclusive controller gate + WLU admission

v0.8 makes the long-lived terminal safe to share between multiple AI observers without giving them multiple keyboards.

The generic `TerminalControlGate` enforces **one writer / many readers**.  Any number of callers may use a read-only `TN5250ObservationSession`, but only one authenticated controller can hold the mutation capability at a time:

```text
                     TN5250LiveSession
                            |
                    TerminalControlGate
                            |
             +--------------+--------------+
             |              |              |
          AI-A            AI-B           AI-C
        CONTROL          OBSERVE         OBSERVE
```

A controller receives a lease-bound `TerminalLeasedController` facade.  The underlying lease object is not exposed, the gate does not publish it through a getter, and actor identity comes from that capability rather than caller-supplied text.  A second controller receives `CONTROL_BUSY`; release/revocation is atomic, and the old facade cannot mutate after handoff.

Every mutation is serialized through the gate and rechecks both:

1. the terminal generation (`STALE_SCREEN` on an old decision); and
2. the external admission reservation (`CONTROL_ADMISSION_INVALID` if the reservation is expired, settled, stale or has a bad proof).

The default controller capabilities deliberately omit `SYSTEM_REQUEST`; it must be granted explicitly.  Field writes, cursor movement/navigation, AID, Error Reset and System Request are separate capabilities.

`TN5250LiveSession` no longer exposes a raw mutable automation port.  It exposes `observerPort()` for read-only clients, and the trusted session owner configures/acquires control with `enableControlGate()` / `acquireControl()`.  Session close, remote EOF, protocol failure, transport failure and strict-device collision revoke any active controller before the terminal is retired.

### WLU boundary

The terminal does **not** implement WLU or crypto.  `TerminalControlGate` accepts an external authority implementing `admit(reservation)`.  The supplied integration regression uses `WLUAuthority` directly, so its SipHash-2-4-128 authenticated reservation is revalidated before every terminal mutation.

The terminal emits unpriced metering evidence such as:

```text
FIELD_WRITE
AID
BYTES_RX / BYTES_TX
SCREEN_UPDATE
HOST_ROUND_TRIP
```

Policy in the WLU package maps those facts to normalized work.  Capacity/admission failure occurs before terminal mutation; settlement of a WLU reservation makes the controller unusable on the very next attempted action.

Validated external integration artifacts from the supplied consolidated roll-up (they are **not vendored** into this package):

```text
oorexx_work_load_units_v0.3.zip
6808638e5cd8c73f453b28d16a3ecb41414d7f4af2c60d2c77e5905e31421713

oorexx_crypto_v0.1.zip
3eab23b5138cba889eb11ea5b93747eb14fca8da0fd4ac936a70174349ae8f3a
```

Run the concrete base suite with `ALCHEMY_OBJECTS_SRC`, `CRYPTO_SRC` and `JOURNAL_POINTED_STATE_SRC`; set `WLU_SRC` as well to enable the optional concrete WLU regression.


## v0.6 structured field navigation and operator-error state

v0.6 turns the live IBM i field topology into an operator-facing terminal surface rather than treating fields only as host READ data.  The safe automation facade now supports `focusField`, `nextInputField`, `previousInputField`, `home`, `typeAtCursor`, and `errorReset` while retaining the existing host-generation stale-screen check.

`focusField` and the next/previous operations navigate actual host-declared input fields in presentation order.  They do not infer edit boxes from text or pixels.  `typeAtCursor`, in contrast, deliberately behaves like terminal keying: if the cursor is in protected space, the 5250 personality enters a first-class `PRE_HELP_ERROR` condition with code `0005` / `PROTECTED_AREA`, locks the keyboard, marks the cursor blinking, and requires `ERROR_RESET` before ordinary navigation/input resumes.  RFC 1205 identifies operator error `0005` as attempting to type where input is not enabled.

`TerminalSnapshot~operatorCondition` exposes the detached condition separately from semantic screen identity.  Generic known-state criteria can match operator state/kind/code when needed, but the live `IBM_I_CHANGE_PASSWORD` state remains the same state regardless of whether a human has wandered into protected space.

Home processing follows the IBM rule: use the last IC address when one exists, otherwise the first non-bypass input field, otherwise row 1/column 1.  Pressing Home while already at home is Record Backspace; v0.6 currently fails closed at that boundary instead of inventing Record Backspace behavior.

The shipped `tests/ibmi_known_states_live.json` is the redacted live PUB400 catalogue supplied after successful observation.  The regression suite reloads it, proves all three exemplars still match uniquely, verifies the exact 128-character change-password field topology at rows 9/12/15 column 47, and verifies that persisted NONDISPLAY exemplars restore no secret bytes.

The datastream machine also recognizes host `WRITE ERROR CODE` (`x'21'`) sufficiently to enter pre-help error state, honor its optional IC, clear pending AID, retain the visible error message as condition evidence, and preserve the SOH-selected error row.  Exact physical-5494 error-line image replacement/restoration and Help/post-help signaling are deliberately still not claimed.

## v0.5 password-expiry and change-password state discovery

Live IBM i acceptance established two distinct post-login outcomes: an invalid credential remains on the `IBM_I_SIGNON` layout with transient error text, while a valid credential with an expired password advances to a fieldless `Sign-on Information` notice.  v0.5 models those semantics explicitly.

`KnownState5250Factory` now recognizes:

```text
IBM_I_SIGNON
IBM_I_PASSWORD_EXPIRED_NOTICE
IBM_I_CHANGE_PASSWORD
```

The password-expired notice requires stable host text (`Sign-on Information`, `Password has expired`, and `Press Enter to change your password`) and zero fields.  The change-password state is learned only from a structured 5250 screen containing the current/new/verification labels and exactly three host-declared NONDISPLAY input fields.  Cursor position is deliberately excluded from its matcher, because a human may move the cursor into a protected area without changing the semantic host state.

`KnownStateCriterion` gains generic `FIELD_COUNT_EQ`; no IBM-specific concept is added to the terminal-neutral core.  The observed `IBM_I_PASSWORD_EXPIRED_NOTICE --ENTER--> IBM_I_CHANGE_PASSWORD` transition is stored as knowledge only and does not authorize the action.

`tools/pub400_password_expiry_probe.rex` is the bounded live acceptance path.  It:

1. requires the persisted `IBM_I_SIGNON` before asking for the existing credential;
2. submits login once;
3. requires/learns `IBM_I_PASSWORD_EXPIRED_NOTICE`;
4. sends exactly one continuation ENTER;
5. captures and, if structurally valid, persists `IBM_I_CHANGE_PASSWORD`;
6. stops without asking for or sending a new password.

```sh
rexx pub400_password_expiry_probe.rex ibmi_known_states.json
```


## v0.4.1 device-name collision handling

The device name supplied to a TN5250 runtime is a **preferred** name, not an assumption that the server must grant it.  Enhanced 5250 Telnet servers may re-request only `DEVNAME` when the requested virtual device is already in use.  Re-sending the same value can cause the server to disconnect the client.

`TN5250TelnetProfile` therefore distinguishes `requestedDeviceName` from the current `deviceName`.  A collision request advances deterministic names (`AIBOT0001` -> `AIBOT0002` -> `AIBOT0003`) while keeping the maximum device-name length at ten characters.  `TN5250RuntimeSession~negotiatedDeviceName` and `~deviceNameCollisionCount` expose the result to trusted diagnostics.

## v0.3 security boundary: runtime versus automation

v0.2 exposed a subtle but important hazard: an AID action could cause a host READ response containing a nondisplay field, and returning the raw response bytes from that same action would hand the secret back to the caller.

v0.3 splits the composed object in two:

```text
TN5250RuntimeSession               trusted transport/wire side
    feedNetwork(bytes)
    drainTerminalOutput()
    raw RFC1205/Telnet response bytes

        |
        +---- automationPort()
                  |
                  v
TN5250AutomationSession            AI/operator-safe side
    snapshot()
    setField()
    moveCursor()
    press()
    systemRequest()

    NO feedNetwork()
    NO raw outbound bytes
    NO model/driver/Telnet/runtime getter
```

`TN5250ActionResult` reports only a Boolean `transportOutputPending`; it never contains the wire bytes.  Nondisplay values remain `<SECRET>`/masked in snapshots, WatchAlong, traces and known-state exemplars.


## v0.4 known-state and credential boundary

v0.4 turns the successful live PUB400 sign-on observation into an executable state-memory/login boundary rather than a one-off screen scrape.

`KnownState5250Factory~ibmISignon()` learns a conservative matcher from a confirmed sign-on snapshot.  It records the exact input-field topology of the exemplar plus stable semantic evidence (user/password labels, keyboard state and cursor placement), while deliberately excluding volatile server/device/news text.  New generic criterion types support case-insensitive row text and field-at-position topology without teaching the generic core anything about IBM i.

The credential path is capability based:

```text
TerminalCredentialProvider
        |
        v
TerminalCredentialBroker
        |  returns trusted lease only
        v
TN5250CredentialLogin~stage()
        |
        +-- requires current snapshot MATCH IBM_I_SIGNON
        +-- finds exactly one display input field + one NONDISPLAY input field
        +-- stages username/password transactionally
        +-- retires lease
        v
SAFE stage result
        reference + field ids + redacted snapshot

        (separate decision)
               ENTER
```

The safe automation facade has no method to acquire or consume a credential lease.  Password bytes never appear in WatchAlong, snapshots, known-state JSON, action traces, safe action results, argv or environment variables in the supplied local login tool.  They exist only in the trusted credential lease/presentation-space/wire path.  Rexx strings cannot promise secure memory wiping, so retiring a lease removes references but does not claim cryptographic zeroization.

Credential staging is deliberately **not** submission.  The username/password pair is prevalidated and applied transactionally; if either field is wrong or too short, the presentation state is restored.  `ENTER` remains a separately logged AID action.

## 5250 workstation datastream

The implementation is based on IBM *5494 Remote Control Unit Functions Reference*, Release 3.1, SC30-3533-04, especially Chapters 15 and 16, with RFC 1205 applied at the TN5250 record boundary and for its documented corrections/additions.

The bounded DP-mode parser currently includes:

- CLEAR UNIT / CLEAR UNIT ALTERNATE (24x80 personality) / CLEAR FORMAT TABLE;
- WRITE TO DISPLAY and the implemented WTD control-character state effects;
- SBA, IC, MC, RA, EA, SOH, TD, WEA and SF;
- FFW parsing and recognized FCWs;
- nondisplay field handling and secret-safe snapshots;
- delayed AID versus pending READ state;
- READ INPUT, READ MDT, bounded READ MDT ALT;
- READ MODIFIED IMMEDIATE ALTERNATE (`x'83'`), including AID `x'00'`;
- conservative 5250 Query Reply;
- fail-closed unsupported command/order handling.

`READ IMMEDIATE` (`x'72'`) is deliberately rejected until the model owns a byte-exact enough format-table/regeneration representation to produce the documented result rather than an approximation.

## RFC 1205 control/session flow

v0.3 adds the terminal-control path separately from ordinary AID/field input:

- System Request produces RFC1205 flags `x'0400'` with opcode NOP;
- Cancel Invite from the host is acknowledged with Cancel Invite as RFC 1205 requires;
- control signals cannot be mistaken for AID bytes.

### SAVE / RESTORE

IBM specifies that SAVE SCREEN includes presentation, format, keyboard, cursor and outstanding READ/AID state, and that the saved representation is workstation-specific and must be returned unchanged by the host.

v0.3 therefore implements an **opaque session-local save image**:

```text
host SAVE
    -> trusted driver captures PrivatePresentationState5250
    -> wire receives ESC RESTORE + opaque ORX1 token

host later returns that image with RESTORE opcode
    -> driver resolves the token
    -> exact private state for this emulator session is restored
```

The saved private object may contain nondisplay field values, but the wire token does not.  This is intentionally not claimed to be byte-compatible with a physical 5494's compressed save image.

## Telnet and TLS

`TelnetMachine` remains a generic incremental Telnet parser.  `TN5250TelnetProfile` handles the 5250 BINARY/EOR/TERMINAL-TYPE/NEW-ENVIRON profile; RFC1205 record framing stays separate from the 5250 workstation datastream.

`TcpTerminalTransport` is plain TCP.

`SocatTlsTerminalTransport` is an optional Unix adapter for environments where ooRexx provides sockets but no native TLS socket class.  It uses `socat`/OpenSSL to establish a TLS tunnel on loopback and then reuses `TcpTerminalTransport`:

- certificate verification is on by default;
- SNI uses the requested host;
- trust-store discovery is portable rather than distro-hard-coded;
- explicit CA file/path overrides are supported;
- then `OOREXX_TERMINAL_CA_FILE` / `OOREXX_TERMINAL_CA_PATH`;
- then OpenSSL `SSL_CERT_FILE` / `SSL_CERT_DIR`;
- then common Debian/Ubuntu, openSUSE/SLES, RHEL/Fedora, Alpine, Arch/p11-kit, BSD and FreeBSD bundle/path locations;
- no plaintext fallback exists;
- absent helper/CA/verification failures fail closed.

Both transports now provide bounded `waitReadable()` / `receiveBytesWait()` operations so a diagnostic terminal does not need to block forever waiting for a host.

## PUB400 live probes

`tools/pub400_probe.rex` remains deliberately observational.  It can negotiate a verified-TLS TN5250 session and render the first structured host screen, including safe field descriptions, but contains no login operation:

```sh
cd tools
rexx pub400_probe.rex
```

Optional arguments are now:

```text
host  port  deviceName  seconds  knownStatePath
```

If `knownStatePath` is supplied and the observed screen satisfies the conservative IBM i sign-on recognizer, the probe persists it as `IBM_I_SIGNON` without sending any field input or AID:

```sh
rexx pub400_probe.rex pub400.com 992 AIBOT0001 30 ibmi_known_states.json
```

The probe never calls `setField`, `press`, `moveCursor` or `systemRequest`.  It responds only to protocol/host-driven requirements such as Telnet negotiation and 5250 Query, then stops once a renderable screen is observed.  Its successful terminal message is explicitly `LOGIN NOT ATTEMPTED`.

After a known-state file has been learned, `tools/pub400_login_once.rex` provides an explicit local-operator acceptance path:

```sh
rexx pub400_login_once.rex ibmi_known_states.json
```

The tool first requires the live screen to match the stored `IBM_I_SIGNON` state.  Only then does it prompt locally for a user profile and read the password from `/dev/tty` with echo disabled.  It stages the pair through a one-shot credential provider, restores terminal echo even on its local error/HALT path, issues `ENTER` as a separate action, and then becomes observational again: it prints the first host screen change and sends no post-login command.  No password is accepted on argv or through an environment variable.

## Existing-device reattach and long-lived sessions

v0.7 stopped treating every live tool run as if it must manufacture a new IBM i terminal.  `TN5250LiveSession` owns the transport and protocol runtime together, allowing one connection to remain OPEN across operator waits and multiple safe automation actions.

DEVNAME collision behavior is now explicit:

```text
ADVANCE
    preferred AIBOT0001 collides
    -> try AIBOT0002

STRICT
    request QPADEV0037
    -> QPADEV0037 or nothing
    -> collision is reported; QPADEV0038 is never emitted
```

For a credential-free check of a previously observed IBM i display:

```sh
cd tools
rexx pub400_resume_device.rex QPADEV0037
```

The default observation window is 60 seconds; pass `0` as the final argument to remain attached until interrupted or the remote side closes:

```sh
rexx pub400_resume_device.rex QPADEV0037 pub400.com 992 0
```

This tool does not attempt authentication or send any AID.  Its purpose is to distinguish an exact-device collision from an available/reconnectable device and to observe whatever screen IBM i actually supplies.  A strict collision closes the newly opened socket rather than silently creating another virtual display.

The long-lived class also separates terminal lifecycle outcomes (`OPEN`, `REMOTE_CLOSED`, `DEVICE_COLLISION`, `ERROR`, `CLOSED`) and treats a quiet host/operator wait as a normal `OPEN` state with no activity.

## WatchAlong and known states

WatchAlong still receives detached immutable snapshots only.  There is no action method on the observer.

Replay and state memory preserve the earlier invariant:

```text
TerminalSnapshot       = evidence
FrozenTerminalState    = evidence at a chosen trace position
KnownTerminalState     = interpretation + matcher + provenance
KnownStateTransition   = observed history
Action authorization   = separate concern
```

That same mechanism is intended to recognize old-system states such as a 5250 inquiry wait, a 3270 console state, or a DEC monitor prompt without making recognition itself an instruction to act.

## Main classes

- `TerminalCore.cls` — detached snapshots, sessions, WatchAlong, trace/replay and known states.
- `TerminalControl.cls` — one-writer control gate, lease-bound controller facade, capability checks and unpriced metering facts.
- `TerminalAlchemy.cls` — Alchemy Objects v0.8 STANDARD-adoption base for stateful terminal/service objects; scalar/value registered-state rule.
- `TerminalOwnership.cls` — persistent one-session owner plus bounded attached observer/controller capabilities.
- `TerminalBroker.cls` — terminal-neutral multi-client service core over one `TerminalSessionOwner`.
- `TerminalBrokerProtocol.cls` — bounded JSON/framing protocol endpoint, safe value projections, bearer/admission-handle authority and replay protection.
- `CharacterGridTerminal.cls` — generic grid terminal model.
- `FieldTerminal.cls` — generic field-oriented terminal model.
- `StreamTerminal.cls` — stream/TTY model proving terminal-family neutrality.
- `Terminal5250.cls` — 5250 presentation space, AID/read/control state and AI-safe agent port.
- `CodePage5250.cls` — IBM037 conversion boundary.
- `TelnetProtocol.cls` — generic incremental Telnet state machine.
- `TN5250Wire.cls` — RFC 1205 logical-record codec and 5250 Telnet profile.
- `DataStream5250.cls` — native 5250 workstation datastream parser/state machine.
- `TN5250Input.cls` — 5250 READ response encoder.
- `TN5250DisplayDriver.cls` — RFC record <-> datastream/presentation driver; trusted SAVE state.
- `TN5250Automation.cls` — trusted runtime and separate safe automation facade.
- `TN5250LiveSession.cls` — long-lived TLS/TN5250 lifecycle owner with strict-vs-advance DEVNAME collision policy.
- `TerminalTransport.cls` — TCP and optional verified `socat` TLS transports.
- `KnownStateJsonStore.cls` — known-state persistence.
- `TerminalCredential.cls` — generic credential provider/broker/lease capability boundary.
- `TN5250CredentialLogin.cls` — conservative IBM i sign-on/change-password state learning and sign-on credential staging coordinator.
- `TN5250PasswordChange.cls` — trusted state-gated transactional current/new/verify password staging; Enter remains separate.

## Deliberate v0.9 boundaries

v0.9 does **not** claim a complete 5250 workstation.  Important remaining work includes:

- byte-exact READ SCREEN / READ IMMEDIATE regeneration-buffer semantics;
- transparent input-field return bytes;
- signed-numeric inbound formatting;
- complete SOH PF-key masking/resequencing;
- exact WRITE ERROR CODE error-line image save/restore plus Help/post-help semantics;
- Attention/Test Request/Help-from-error signal details;
- physical-5494-compatible SAVE/RESTORE serialization (the current implementation uses an honest session-local opaque image);
- WDSF GUI/window/selection/scroll-bar execution;
- complete extended-attribute planes;
- DBCS/ideographic operation and CCSIDs beyond IBM037;
- native TLS inside ooRexx itself.

The packaged test suite does not perform an external PUB400 login.  The shipped redacted known-state fixture is derived from the user-confirmed live PUB400 run; live tools remain explicit local acceptance paths.

## Validation

The package is exercised under the supplied Open Object Rexx 5.3.0 r13196 build.  Run:

```sh
./run_tests.sh
```

The self-contained suite includes generic terminal/replay tests, one-writer control-gate tests, read-only observer tests, 5250 datastream and wire tests, strict/advance DEVNAME collision policy, long-lived session lifecycle tests, learned 5250 known-state persistence, transactional credential staging and secret-boundary regressions, System Request/Cancel Invite, opaque SAVE/RESTORE, full synthetic TN5250 vertical composition, plain TCP loopback, and a verified local TLS fixture.

Set `ALCHEMY_OBJECTS_SRC`, `CRYPTO_SRC` and `JOURNAL_POINTED_STATE_SRC` to the external Alchemy v0.8, Crypto v0.1 and Journal Pointed State v0.1 source roots. Set `WLU_SRC` to the external WLU v0.12 source root to run the concrete admission/proof integration. None of these dependencies is vendored into Terminal Machine.

### TLS trust-store discovery

Verified TLS does not assume a particular Linux distribution.  With no explicit
trust argument, `SocatTlsTerminalTransport` resolves trust in this order:

1. `OOREXX_TERMINAL_CA_FILE` / `OOREXX_TERMINAL_CA_PATH`;
2. OpenSSL `SSL_CERT_FILE` / `SSL_CERT_DIR` when usable;
3. common system bundle locations (including openSUSE/SLES, Debian-family,
   RHEL/Fedora, Alpine, Arch/p11-kit and BSD layouts);
4. common hashed OpenSSL CA directories via `capath`.

An explicitly supplied missing CA file/path fails immediately and is not silently
replaced with another source.  The live probe prints the selected trust source,
for example `SYSTEM_BUNDLE cafile=/etc/ssl/ca-bundle.pem` on a typical
openSUSE/SLES installation.  Verification failures never fall back to plaintext
or `verify=0`.

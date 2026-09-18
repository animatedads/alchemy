# v0.21

- Added `TerminalEmulatorOrchestration.cls`, binding the v0.20 exact-token checkpoint boundary to fixed emulator instruction/event execution flows without exposing execution tickets to handlers.
- Added immutable `TerminalEmulatorEvent` and `TerminalEmulatorEventHistoryEntry` evidence. History records only event identity, retry lineage, checkpoint id, outcome, terminal phase, bounded fault text, progress marker and value-free phase status; fetch/decode/execute values and live authority objects are not retained.
- Added explicit `TerminalEmulatorInstructionPipeline` and `TerminalEmulatorEventHandler` marker mixins. Instruction execution uses fixed `emulatorFetch` -> `emulatorDecode` -> `emulatorExecute`; non-instruction events use fixed `emulatorHandleEvent`. Arbitrary caller-supplied method names are not accepted.
- Added `TerminalEmulatorEventOrchestrator`: every accepted attempt checkpoints before handler execution, commits only through the internally retained exact `TerminalEmulatorExecutionTicket`, and automatically rolls back on handler `TerminalResult` failure or trapped ooRexx `SYNTAX`.
- Added explicit retry lineage. `retryInstruction()` / `retryEvent()` accept only retained `ROLLED_BACK` attempts, create a new checkpointed attempt and link immutable debugger evidence through `retryOfEventId`; committed attempts cannot be reused as retry sources.
- Added bounded orchestration history with id-index eviction and detached array/phase projections so caller mutation cannot rewrite retained evidence. Event handler validation happens before checkpoint creation or dispatch accounting.
- Added `test_terminal_emulator_orchestration.rex`, expanded Alchemy reference-boundary coverage, and added `examples/emulator_instruction_orchestration.rex` demonstrating missing opcode -> exact rollback -> code repair -> linked retry while the failed journal future remains inspectable.
- Re-dogfooded with user-supplied Semantic Source Control v0.2.2. Its complete r13196 suite passes and the Terminal-discovered `::constant`/`::attribute` blind spot is fixed (`CONSTANT_VALUE_CHANGED`, `ATTRIBUTE_ACCESS_CHANGED`, accessor-body implementation tracking). Its new batched SHA-256 path reduces hash process creation, but a full v0.21 production-source scan still exceeded the 360-second certification window after a 23.16-second v0.20 source baseline, so SSC remains supplementary rather than the sole release gate.
- Added an authoritative `SSC_MANIFEST` for `TerminalMachine`, lineage `MAIN`, semantic source level `1`. This is intentionally independent of the v0.21 product release label; future source-level movement must be an explicit semantic-source decision rather than version-number inference.
- Retained v0.20 time-travel, v0.19 emulator-only live-repair restrictions and all live-terminal one-writer, WLU, NONDISPLAY/raw-wire and IBM i signoff boundaries unchanged.

# v0.20

- Added `TerminalEmulatorTimeline`, a read-only retained-branch debugger over v0.19 journal-pointed emulator state.
- Added detached `TerminalEmulatorCheckpointEvidence` with pointer-only component positions and scalar-sanitised checkpoint metadata; object-valued metadata is never exported by exact reference.
- Added `TerminalEmulatorBranchEvidence` containing value-free undo/redo topology, journal node/tag/timestamp evidence and changed-key names. Returned plan structures are deep copied so callers cannot mutate retained evidence.
- Added explicit `materialiseCheckpoint()` / timeline `materialise()` for value-bearing old-state reconstruction without moving live component heads; the immutable/copy-on-write journal value rule remains in force and this is not a durable serialisation claim.
- Added `TerminalEmulatorExecutionBoundary` and immutable exact-object `TerminalEmulatorExecutionTicket` for checkpoint-before-speculation, one active attempt, exact-token commit/rollback and stale/forged ticket refusal.
- Rollback restores all registered emulator components to the exact attempt checkpoint; commit keeps the current forward branch and can publish progress through the existing State Progress Watcher path.
- Removed any public active-ticket getter so possession of the execution boundary does not reveal the exact completion/rollback capability issued by `begin()`.
- Extended Alchemy reference-boundary tests so timeline machine references and execution-boundary machine/ticket/checkpoint capabilities remain absent from FULL state while safe scalar counters/state remain visible.
- Added `test_terminal_emulator_timeline.rex`, `test_terminal_emulator_execution_boundary.rex` and `examples/emulator_time_travel_debugger.rex`.
- Retained v0.19 emulator-only/live-patch restrictions and all v0.18 service, one-writer, external-WLU, NONDISPLAY/raw-wire and IBM i signoff boundaries unchanged.

# v0.19

- Added `TerminalEmulatorJournal.cls`, integrating external ooRexx Journal Pointed State v0.1 as a terminal-neutral emulator/testbed state primitive without vendoring it.
- Added `TerminalJournalComponent` wrappers for branching diff-backed state, batched meaningful edits, non-mutating reconstruction and State-of-the-Nation participation.
- Added `TerminalEmulatorStateMachine` for pointer-only multi-component checkpoints, preflighted all-component restore, retained checkpoint navigation and progress/stall watching.
- Added `TerminalEmulatorPatchable` as an explicit live-repair opt-in marker and `TerminalEmulatorRecoveryCoordinator` for code-forward/state-backward missing/faulty instruction repair.
- Live repair revalidates response-overridden targets and refuses merely method-shaped objects; `LIVE_HOST` journal mode is rejected so emulator rewind cannot become remote terminal/session/service authority.
- Reviewed the supplied Queue Fabric two-process live-patch demonstration and retained its transport-neutral lesson without making Queue Fabric a hidden Terminal Machine dependency.
- Added executable emulator branching/recovery and Alchemy reference-boundary regressions plus `examples/emulator_journal_repair.rex`.
- Retained v0.18 supervised multi-client service operation, one-writer/many-reader ownership, external WLU v0.12 admission, NONDISPLAY/raw-wire secrecy and explicit IBM i signoff separation.

# v0.18

- Added `TerminalBrokerServiceSupervisor`, an Alchemy-backed operational control layer above the v0.17 service lifecycle which never exports or registers the live lifecycle/host/endpoint/broker authority object.
- Added detached `TerminalBrokerOperationalHealth` evidence and fail-closed `requireReady()`. `HEALTHY` requires lifecycle `RUNNING`, socket service `RUNNING`, listener `LISTENING`, live acceptor, valid bound port/worker limit, protocol endpoint `OPEN`, retained broker `OPEN`, and no lifecycle failure.
- Expanded `TerminalBrokerServiceStatus` with detached socket service generation, worker limit, acceptor/counter evidence, listener state, socket operational error, broker client capacity/control state and active controller principal. Optional scalar copying preserves compatibility with lightweight fixtures.
- Kept historical socket errors separate from lifecycle failure (`socketLastError` vs `lastError`) so monitoring sees transport evidence without converting a completed/rejected connection into false terminal authority or implicit failure semantics.
- Added controlled `start()` and `shutdown()` operations. Start launches only a stopped lifecycle then requires readiness; shutdown preserves v0.17 drain -> worker completion -> protocol quiesce ordering and leaves the retained terminal broker open.
- Kept IBM i orderly signoff as a separate protected security-boundary operation after quiesce. Service shutdown never becomes terminal signoff/close authority.
- Added `test_terminal_broker_operations.rex` for health/readiness, cross-layer disagreement/degradation, controlled shutdown ordering, idempotent quiesced shutdown, restart refusal, launch failure evidence and Alchemy reference-boundary checks.
- Added real cross-process `test_terminal_broker_operations_service.sh`, proving two independently authenticated concurrent clients are observed through the operational health surface before controlled drain, after which lifecycle/protocol are QUIESCED, listener is stopped and broker close count remains zero.
- Rebased release evidence on updated `oorexxapis(20260825-083438).zip`; Terminal Machine's external dependencies remain Alchemy Objects v0.8, ooRexx Crypto v0.1 and WLU v0.12. Same-version duplicate files in the wider roll-up are resolved by SHA/content/lineage rather than filename suffix ordering.
- Retained all v0.17 persistent ownership, one-writer control, protocol quiesce, exact IBM i signoff, NONDISPLAY/raw-wire secrecy, verified TLS and helper-lifecycle rules unchanged.

# v0.17

- Added persistent multi-client hosting to `TerminalBrokerLocalSocketHost`: one private blocking acceptor plus a bounded set of concurrent ooRexx connection workers around the existing authenticated `terminal.broker.socket/0.1` transport.
- Added service lifecycle evidence/counters, worker limit/generation, active/peak/completed connection counts, and `launchService()`, `requestDrain()`, `awaitDrain()` and `serviceStatus()` without exposing sockets, workers, peer keys, endpoint references or service authority through Alchemy state.
- Froze `trustPrincipal()` bindings while the service is running/draining and prevented synchronous `serveOne()` from stealing the persistent listener.
- Added a loopback wake of blocking `accept()` for graceful drain, following the first-party ooRexx server pattern; drain stops new admission and waits for already accepted bounded workers before listener shutdown.
- Contained unexpected endpoint `SYNTAX` failures to the affected worker, guaranteed socket cleanup/active-worker completion accounting, and kept the persistent service drainable; unexpected acceptor failures become explicit service `ERROR` rather than an indefinite drain wait.
- Added `TerminalBrokerProtocolEndpoint~quiesce()`: endpoint-local client/controller bearer mappings, admission handles and replay state are revoked without closing the retained broker/session. A detach failure yields `QUIESCE_FAILED` and subsequent remote requests fail closed.
- Added `TerminalBrokerServiceLifecycle` to enforce shutdown ordering: socket drain -> protocol quiesce -> optional trusted host signoff. Generic service drain never closes the terminal.
- Added broker-owned IBM i orderly signoff. It requires exact `IBM_I_MAIN_MENU`, zero retained remote clients/controllers, ordinary external admission/WLU proof, literal option `90`, and exactly one `ENTER`; after ENTER it performs observation only.
- Hardened signoff completion semantics: only confirmed remote close permits final broker close. A changed screen, ENTER failure, observation error or timeout is unconfirmed evidence and leaves the broker open/quiesced for diagnosis rather than using generic close as a substitute for host signoff.
- Added/expanded regressions for persistent service lifecycle, protocol quiesce/failure, exact IBM i signoff ordering/fail-closed outcomes, worker exception containment, and a real cross-process two-client authenticated service (`peak=2`) followed by graceful drain.
- Retained v0.16 loopback HMAC authentication/integrity, v0.15 secret-safe protocol boundary, v0.14 one-session broker, v0.13 Alchemy reference boundary, one-writer generation checks, external WLU policy, verified TLS and socat lifecycle discipline.

# v0.16

- Added `TerminalBrokerLocalSocketHost` and `TerminalBrokerLocalSocketClient`, an actual ooRexx-owned authenticated local IPC adapter around the v0.15 `TerminalBrokerProtocolEndpoint`. Socket lifecycle remains outside terminal/broker ownership: stopping or disconnecting the transport does not close the endpoint, broker, owner or live terminal session.
- Kept the listener hard-bound to IPv4 loopback (`127.0.0.1`). The supplied r13196 `Socket` class exposes AF_INET rather than AF_UNIX, so v0.16 does not fake Unix-domain-socket semantics through a helper process. Accepted peer addresses are checked again before protocol handling.
- Added `terminal.broker.socket/0.1`: exact bounded 8-hex record framing, HMAC-SHA-512 mutual authentication, independent 256-bit client/server nonces, exact principal/key-id binding, and strictly increasing per-connection sequence numbers.
- Added a strict key boundary: there is no built-in/default HMAC key, configured peer key bytes have no getter and are never registered as Alchemy state, and the client key/nonces/socket/framer are likewise omitted from FULL state.
- The authenticated transport principal is established by the socket handshake and passed separately to `TerminalBrokerProtocolEndpoint~handleFrame(principal, frame)`. A JSON body cannot self-assert or replace the transport identity.
- Every broker request and broker response is separately HMAC-authenticated. `BYE` / `BYE_ACK` is authenticated as well. Wrong-key clients, forged request MACs, forged server challenges and forged response MACs are rejected before authority is accepted/used.
- Added bounded socket I/O inactivity using r13196 `SO_RCVTIMEO` / `SO_SNDTIMEO` in milliseconds (30,000 ms default, 100..3,600,000 configurable) so an accepted local peer cannot hold the synchronous v0.16 service path forever without sending data.
- Retained a bounded per-connection request count (256 default) and record limit (262,144 bytes default). BYE remains possible after the request budget is exhausted so a compliant peer can close cleanly.
- Added `test_terminal_broker_socket.rex` for Alchemy/reference boundaries and authenticated-text binding, plus cross-process socket fixtures covering successful multi-request use, principal-body spoof resistance, wrong-key rejection, forged request rejection, forged server authentication and forged response rejection.
- Advanced Terminal Machine adoption to Alchemy Objects v0.8 while preserving the scalar/value-only registration rule; acceptance verifies base version 0.8, preferred INIT construction and the v0.8 cooperative-interposition evidence fields without exporting interposition/provider objects.
- The socket layer provides local authentication and integrity, not confidentiality. v0.15 still forbids remote NONDISPLAY input and masks secret presentation data. A future AF_UNIX or TLS adapter can implement the same endpoint contract without changing terminal ownership semantics.
- Re-resolved the updated `oorexxapis(20260824-191006).zip` by component identity/content: Alchemy Objects v0.8, ooRexx Crypto v0.1 and WLU v0.12 are the external Terminal Machine acceptance dependencies. Queue Fabric v0.9-dev4 and Secret Broker v0.2 were reviewed as sibling facilities and were not silently added as Terminal Machine dependencies.

# v0.15

- Added IPC-neutral `TerminalBrokerProtocolEndpoint` above the v0.14 persistent broker. A surrounding trusted transport supplies authenticated principal identity separately from the JSON body, so a request cannot self-assert its principal.
- Added `TerminalBrokerFrameCodec` with an exact eight-hex-digit payload-length header, bounded frame sizes and fail-closed rejection of invalid headers, incomplete frames and trailing data.
- Added opaque client/controller bearer authority. No fallback token generator exists: the host must provide `issueToken(purpose, principal, bindingId)`, and active-token collision/length checks are enforced.
- Added host-side admission-handle registration so real external WLU/admission reservations remain inside the trusted process and cross IPC only as opaque handles. Successful control acquisition consumes the handle.
- Preserved one-writer handoff without leaking target authority: the old controller's `CONTROL_HANDOFF` response never contains the target controller token; the target principal retrieves its own token with its own client bearer through `CONTROL_STATUS`.
- Added allow-listed serialization of snapshots, broker status, known-state evidence and meter facts instead of arbitrary ooRexx object serialization.
- Hardened NONDISPLAY projection twice: field values serialize as `<SECRET>` and presentation cells covered by NONDISPLAY fields are re-masked, including fields which wrap across 80-column rows.
- Denied remote `SET_FIELD` and cursor-relative `TYPE_AT_CURSOR` into NONDISPLAY fields before mutation. Trusted credential/password-change staging remains outside the remote broker protocol.
- Kept AID/System Request wire flushing below the owner/broker boundary so raw TN5250 READ-response bytes are never returned by the serialized safe API.
- Added bounded request-id replay/idempotency while deliberately retaining no serialized request body or rejected input text. Replay records contain only the request operation and encoded safe response, keyed by authenticated principal/request id; cross-operation request-id reuse is rejected.
- Upgraded the terminal Alchemy integration to `alchemy_objects_v0.7`. `TerminalAlchemyObject` now uses the preferred `self~init:super(...)` base-construction path and supplies STANDARD-adoption metadata; regression checks require INIT construction provenance and no legacy-entrypoint warning.
- Preserved the v0.13 scalar/value-only Alchemy state rule at the protocol layer. Broker/token maps, endpoint capability objects, admission reservations, replay entries, sealer/capability authority and other live/mutable references remain unregistered even under FULL introspection.
- Added `test_terminal_broker_protocol.rex` covering framing, authenticated-principal/token binding, admission handles, one-writer acquisition/handoff, safe projection, pre-mutation secret-field rejection, replay behavior, reference-boundary introspection and endpoint close.
- Revalidated concrete external admission against `oorexx_work_load_units_v0.11` and `oorexx_crypto_v0.1`; no dependency is vendored into Terminal Machine.
- Retained confirmed PUB400 state ordering/signoff policy, known-state-before-action discipline, verified TLS, strict helper lifecycle and the rule that generic broker/owner close is not IBM i signoff authority.

# v0.14

- Added terminal-neutral `TerminalSessionBroker`, the service core above `TerminalSessionOwner`, so one process can retain the only real terminal owner while AI/operator participants receive bounded broker-side capabilities.
- Added `TerminalBrokerClient`, a read-only client facade which delegates only detached observation and known-state reads; attaching a client creates an owner-side observer against the existing session and never opens another terminal connection.
- Added `TerminalBrokerController`, a bounded one-writer facade over the owner-side controller. External admission/WLU proof still occurs in the existing control gate, generation checks remain mandatory, and secret-capable TN5250 wire flushing remains below the broker inside the trusted owner.
- Preserved exact issued-object capability checking at both layers: forged/copied client ids, principals and lease ids do not reproduce authority.
- Preserved non-overlapping controller handoff across the broker boundary: release old -> prove no controller -> acquire target at current generation -> issue new broker controller. No keystroke/action queue was added.
- Detaching a broker client which holds control revokes the owner-side controller before invalidating/removing the client capability.
- Added detached `TerminalBrokerStatus` scalar evidence for service monitoring without exporting owner/live references.
- Extended the v0.13 Alchemy reference rule to broker objects: retained owner, owner-side observer/controller capabilities, client tables, broker back-references, key/sealer objects and other live/mutable authority are never registered as state. FULL introspection is regression-tested.
- Added `test_terminal_broker.rex` for one-session/many-client behavior, exact capability identity, one-writer control, handoff, detach/close invalidation, secret/reference boundaries and detached status.
- Added `test_tn5250_broker_boundary.rex` proving the broker composes with the actual `TN5250LiveSession` ownership gate: raw retained live-session references still cannot open/pump/control/close around the owner, client attachment creates no new TN5250 transport, semantic tracker access survives the broker, and generic broker close sends no invented host action.
- Kept the broker as an IPC-neutral service core. v0.14 does not add a daemon, socket protocol or cross-process rendezvous format merely for transport convenience.
- Retained PUB400 confirmed-state ordering/signoff policy, WLU external admission/accounting, NONDISPLAY secret redaction, verified TLS and forced TERM->KILL socat cleanup unchanged.

# v0.13

- Hardened the Alchemy disclosure boundary after verifying that `alchemy_objects_v0.4.3` `FULL` registered-state introspection returns registered object variables by exact reference, not as detached copies. A parent-v0.12 reproducer confirmed that an attached observer's registered `owner` value was the exact `TerminalSessionOwner` object.
- Established a Terminal Machine rule: Alchemy registered state is value evidence only. Mutable implementation objects, capability/authority objects, secret-capable runtimes, transports, reservations, key/sealer boundaries and mutable internal collections are never registered as state variables.
- Removed exact-object state registration from `TerminalSessionOwner`, `TerminalAttachedObserver`, `TerminalAttachedController`, `TN5250LiveSession` and `TerminalControlGate`, including the live-session ownership capability, raw TN5250 runtime, transport, admission reservation and leased-controller paths.
- Removed mutable collection/object alias registration from `TerminalTrace`, `TerminalReplay`, `TerminalWatchAlong`, `TerminalKnownStateTracker`, `KnownStateCatalog` and `TerminalSession`. Their safe scalar/customer state remains inspectable and their existing explicit methods continue to return detached/copy-safe evidence where defined.
- Corrected an important v0.12 gap: the private ownership token was omitted from `TerminalSessionOwner` state, but the same exact capability was still reachable as `TN5250LiveSession`'s registered `ownershipOwner` under `FULL`; v0.13 removes that route as well as owner back-references from attached observer/controller state.
- Added `test_alchemy_reference_boundary.rex`, exercising `FULL` introspection across the terminal Alchemy object family with active/non-nil authority objects and asserting that no live reference/capability keys are emitted. Safe scalar evidence such as ownership status and opaque lease id remains available.
- No terminal protocol, PUB400 state-machine, WLU admission, one-writer control, secret staging or verified TLS behavior was relaxed.

# v0.12

- Added generic process-resident `TerminalSessionOwner` for one persistent live terminal connection with many attached read-only observers and at most one attached controller.
- Added an unexported exact-object live-session ownership capability retained only inside `TerminalSessionOwner`. Once `TN5250LiveSession` is claimed, neither retained raw references nor possession of the public owner facade can bypass the owner for open/close, network pumping, known-state attachment, control-gate operations or secret-capable terminal-output flushing. The token is deliberately omitted from Alchemy registered state so even `FULL` sealed state introspection cannot delegate it.
- Added `TerminalAttachedObserver` and `TerminalAttachedController` Alchemy-backed capabilities; raw live-session, admission reservation and underlying `TerminalLeasedController` objects never cross the attachment boundary.
- Added explicit controller handoff as release -> verified no-controller -> acquire target observer at the then-current terminal generation; no stale keystroke/action queue exists.
- Detaching the observer holding control revokes the underlying control lease before invalidating the observer attachment.
- Owner-mediated AID/System Request operations flush trusted TN5250 output internally without exposing secret-capable READ response bytes.
- Added owner-mediated semantic tracker attachment and refresh of the cached observation port so already attached/new observers see the live known-state tracker instead of a stale pre-tracker facade.
- Added duplicate-principal detection before capacity reporting so a repeated attachment is identified deterministically as `OBSERVER_ALREADY_ATTACHED`.
- Preserved direct trusted `TN5250LiveSession` behavior for unclaimed fixtures/one-shot tools; ownership enforcement activates only after an explicit claim.
- Added `test_terminal_ownership.rex` and `test_tn5250_session_ownership.rex`, covering one physical open/close, many readers, exact capability identity, no bypass through retained live-session references or the public owner facade, non-overlapping handoff, owner-only pump/flush, semantic observer refresh and Alchemy disclosure boundaries.
- Retained v0.11 semantic tracker/device identity, v0.10 Alchemy integration, v0.9.2 PUB400 ordering/signoff, WLU admission, secret redaction and verified socat teardown.

# v0.11

- Added generic `TerminalKnownStateTracker`, a read-only Alchemy-backed watcher which continuously interprets committed detached snapshots through a `KnownStateCatalog` without gaining any mutation authority.
- Added detached `TerminalKnownStateObservation` history with current status/state/generation, previous distinct known state and transition count; duplicate or stale generations cannot rewind semantic state or fabricate transitions.
- Added `TN5250RuntimeSession~attachKnownStateCatalog()` and semantic read methods on `TN5250ObservationSession`; the observer remains incapable of AID/field mutation.
- Added `TN5250LiveSession~attachKnownStateCatalog()` and CUSTOMER-visible current semantic status/id/generation while retaining the tracker/catalogue itself as INTERNAL.
- Added `TN5250DeviceIdentity` to keep requested DEVNAME, client-selected/negotiated DEVNAME and host-observed sign-on `Display name` as separate evidence sources.
- Server-assigned PUB400 devices such as `QPADEV0012` are now surfaced as `assignedDeviceName` / `effectiveDeviceName` with source `HOST_SIGNON_SCREEN` instead of being misrepresented by a blank negotiation field.
- Conflicting host-screen vs negotiated device evidence is retained and explicitly marked inconsistent rather than silently choosing one historical story.
- Default live control-gate scope now uses an already learned effective device identity when available.
- Updated PUB400 probe/login/password-recovery tools to report the host display device; ordinary login/signoff also reports live semantic tracker state.
- Added `test_known_state_tracker.rex` and `test_tn5250_device_identity.rex`; extended live-session regression for semantic tracker attachment and device-source refresh.
- Retained v0.10 Alchemy disclosure, v0.9.2 password-expiry/signoff ordering, WLU admission, one-writer control, secret redaction and verified socat teardown.

# v0.10

- Added `TerminalAlchemyObject`, derived from the supplied `alchemy_objects_v0.4.3` `AlchemyObject` base.
- Migrated stateful terminal/service objects to the Alchemy base: `TerminalTrace`, `TerminalReplay`, `TerminalWatchAlong`, `KnownStateCatalog`, `TerminalSession`, `TerminalControlGate`, and `TN5250LiveSession`.
- Deliberately kept detached immutable evidence/value classes outside the mutable Alchemy lifecycle base so snapshot/evidence immutability is not weakened by observation telemetry.
- Added structured Alchemy metadata, disclosure-labelled state declarations, method contracts, lifecycle/use telemetry and bounded lifecycle/authority/observation instrumentation to the migrated objects.
- Initially registered trusted TN5250 runtime, active external admission reservation, and Alchemy key/authority boundaries as SECRET for bounded disclosure; v0.13 later supersedes this after proving that `FULL` emits registered values by exact reference.
- Added optional sealer/capability-authority constructor tails to migrated objects without breaking existing call signatures.
- Propagated an optional Alchemy evidence/capability configuration from `TN5250LiveSession` into its `TerminalControlGate`.
- Added `test_alchemy_base_integration.rex`, including SipHash-sealed PUBLIC/CUSTOMER introspection and proof that CUSTOMER WatchAlong introspection exposes generation/capacity but not internal history.
- Added Alchemy inheritance/surface-contract assertions to live-session and exclusive-control-gate regressions.
- Made `ALCHEMY_OBJECTS_SRC` and `CRYPTO_SRC` explicit required test dependencies; optional WLU regression now uses `WLU_SRC` and was validated with the roll-up's `oorexx_work_load_units_v0.3`.
- Retained all v0.9.2 PUB400 password-expiry ordering, MAIN-menu 90 signoff, secret staging, one-writer control, stale-screen protection, verified TLS and stuck-socat cleanup behavior.

# v0.9.2

- Made the live PUB400 expired-password state sequence mandatory: `IBM_I_SIGNON -> IBM_I_PASSWORD_EXPIRED_NOTICE -> IBM_I_CHANGE_PASSWORD`; direct sign-on-to-changer shortcuts are rejected.
- Added `TN5250PasswordExpiryFlow` with fail-closed phase tracking and regression coverage for out-of-order/replayed states.
- Learned the successful live password-change result as `IBM_I_MAIN_MENU`, including the explicit `90. Sign off` option and host command field at row 20, column 7, length 153.
- Added `KnownState5250Factory~ibmIMainMenu()` and `~findMainMenuCommandField()` for conservative structured recognition.
- Added trusted `TN5250Signoff~stage90()`: option 90 is staged only after an exact `IBM_I_MAIN_MENU` match; it does not press Enter.
- Updated `pub400_change_password_once.rex` so the only permitted post-password-change action is `90` + one explicit ENTER on the confirmed main menu. Any other result receives no further terminal input.
- After signoff ENTER the tool waits only for remote close or the first changed screen, sends no more input, and requires the TLS helper to close cleanly.
- Added a live `IBM_I_CHANGE_PASSWORD -- ENTER --> IBM_I_MAIN_MENU` observed transition as knowledge, not action authority.
- Added main-menu/signoff and strict flow-order regressions.
- Added `pub400_login_signoff_once.rex` for the normal post-recovery path: confirmed sign-on -> confirmed IBM_I_MAIN_MENU -> option 90 -> one signoff ENTER -> verified TLS close.

# v0.9.1

- Fixed external `socat` TLS helper lifecycle after live PUB400 evidence showed a helper could remain running and retain an IBM i device session.
- Capture the exact helper PID at launch and verify command ownership before signalling it; never blindly kill a potentially reused PID.
- Close now performs loopback close, TERM + bounded wait, then KILL + bounded wait when required, and reports `TLS_HELPER_STOP_FAILED` if a live helper survives.
- Treat zombie/defunct helpers as stopped network resources rather than confusing `kill -0` liveness with an active session.
- Added `UNINIT` last-resort cleanup to `SocatTlsTerminalTransport`, matching ooRexx socket lifecycle practice.
- Added strict numeric/range validation for the TLS peer port before shell command construction.
- `TN5250LiveSession~close()` now propagates transport-close failure instead of unconditionally claiming success.
- Added top-level HALT cleanup to PUB400 probe/login/password-expiry/password-change tools.
- Added TLS lifecycle regressions proving ordinary helper exit and TERM-to-KILL escalation against a deliberately SIGSTOP-ed helper.
- Revalidated the complete terminal suite and external WLU v0.2.1 / crypto v0.1 integration under ooRexx 5.3.0 r13196.

# v0.9

- Added trusted `TN5250PasswordChangeLease` and `TN5250PasswordChange~stage()` for the confirmed IBM i `IBM_I_CHANGE_PASSWORD` state.
- Added public structured `KnownState5250Factory~findChangePasswordFields()` so semantic recognition and credential staging share one field-mapping rule.
- Added trusted transactional three-NONDISPLAY-field staging in the 5250 runtime; any failure restores the complete pre-stage presentation state.
- Kept the triple-secret primitive off `TN5250AutomationSession`; observer snapshots remain `<SECRET>` and action traces never contain current/new password bytes.
- Password-change staging still does not press Enter; AID submission remains an independent operation.
- Added `tools/pub400_change_password_once.rex`: exact known-state sign-on -> expired notice -> change-password flow, hidden `/dev/tty` prompts, local new-password confirmation, one password-change Enter, and no post-change command.
- Explicit DEVNAME in the recovery tool uses `STRICT` collision behavior rather than advancing to another virtual display.
- Added `test_password_change_stage.rex` covering exact field mapping, secret redaction, trusted-wire field values, wrong-state non-consumption and transactional overflow rollback.
- Revalidated WLU v0.2.1 / crypto v0.1 integration with admission-before-mutation unchanged.

# v0.8

- Added generic `TerminalControlGate` with hard one-writer/many-reader semantics for long-lived shared terminals.
- Added lease-bound `TerminalLeasedController`; the actual lease object is private to the gate/controller facade and is not discoverable through an active-lease getter.
- Added explicit control capabilities for field writes, cursor movement, field navigation, AID, Error Reset and System Request; System Request is not in the default grant.
- Revalidate external authenticated admission before every mutation and revoke control immediately if the reservation expires, is settled, becomes stale or fails proof verification.
- Preserve the existing host-generation stale-screen check inside the serialized control gate.
- Added unpriced terminal metering facts (`FIELD_WRITE`, `AID`, `BYTES_RX`, `BYTES_TX`, `SCREEN_UPDATE`, `HOST_ROUND_TRIP`) while leaving valuation to WLU policy.
- Added `TN5250ObservationSession`, a read-only live observer facade with snapshot/history access and no mutation methods.
- Removed the raw mutable automation port from `TN5250LiveSession`; trusted one-shot fixtures can still instantiate `TN5250RuntimeSession` directly.
- Added live-session `enableControlGate`, `acquireControl`, trusted revoke/status APIs, and automatic control revocation on close/EOF/protocol/transport/device-collision failure.
- Added concrete integration with external `oorexx_work_load_units_v0.2.1` / `oorexx_crypto_v0.1`: WLU capacity denial leaves the terminal untouched, WLU proof admission grants control, settlement invalidates further mutation, and a tampered reservation is rejected by the MAC.
- Added regressions for controller contention, atomic handoff, capability denial, forged lease objects, stale generations, admission expiry, live observer immutability, close-time revocation and WLU-backed control.

# v0.7

- Added `TN5250LiveSession`, a trusted long-lived owner for the TLS transport and TN5250 runtime so one authenticated IBM i connection can remain open while WatchAlong/automation operate against the same device session.
- Added explicit DEVNAME collision policies: `ADVANCE` for fresh-development device allocation and `STRICT` for exact-device reattach/resume attempts.
- In `STRICT` mode, a repeated enhanced-Telnet DEVNAME request is surfaced as `TN5250_DEVICE_COLLISION`; no substitute name is emitted and the rejected connection is closed immediately.
- Preserved requested device identity separately from negotiated device candidate and exposed collision state/count to trusted lifecycle code.
- Added bounded `pumpOnce()` semantics for long-lived sessions: operator silence is ordinary OPEN/no-activity state; remote EOF, device collision and transport/protocol failure are distinct lifecycle states.
- Added trusted `flushTerminalOutput()` for sending password-bearing READ/AID responses without exposing raw bytes to the automation facade.
- Added `pub400_resume_device.rex`, a credential-free strict-device observation tool for probing an existing display such as `QPADEV0037`; it never sends field input/AIDs or advances to another device name.
- Added regressions proving strict collisions never emit `QPADEV0038`, long-lived quiet sessions stay open, and remote EOF is represented separately from an error.

# v0.6

- Added generic detached `TerminalOperatorCondition` evidence plus known-state criteria for operator state, error kind and error code.
- Added structured field navigation: `focusField`, `nextInputField`, `previousInputField`, and IBM Home semantics based on the last IC / first non-bypass field fallback.
- Added cursor-relative `typeAtCursor` as a deliberately terminal-faithful operation distinct from `setField`.
- Typing in protected space now enters 5250 `PRE_HELP_ERROR` with operator error `0005`, locks input, blinks the cursor, and advertises `ERROR_RESET` recovery.
- Added Error Reset restoration of the previous keyboard/session/blink state; normal navigation/input is inhibited while the operator error is active.
- Kept cursor-relative text action traces content-free (`<TEXT>`) so typing in NONDISPLAY fields cannot leak secrets through audit/WatchAlong.
- Added conservative host `WRITE ERROR CODE` (`x'21'`) handling: optional IC, pre-help state, pending-AID clear, safe visible-message evidence and SOH ERR-row retention. Exact error-line image/Help/post-help semantics remain a deliberate boundary.
- Added fail-closed Home-at-home behavior because IBM defines that second Home as Record Backspace, which is not yet implemented.
- Added the user-confirmed redacted PUB400 known-state catalogue as a live regression fixture; all three exemplars round-trip and uniquely re-match after JSON load without restoring nondisplay bytes.
- Added regressions reproducing the real protected-area cursor mistake, structured navigation over the live 128-character password-field topology, secret-safe cursor typing, stale generation rejection, host WRITE ERROR CODE, and live-fixture matching.

# v0.5

- Added `IBM_I_PASSWORD_EXPIRED_NOTICE`, learned from the confirmed live IBM i fieldless Sign-on Information screen after successful authentication with an expired password.
- Added `IBM_I_CHANGE_PASSWORD`, learned only from a structured 5250 panel with current/new/verification labels and three host-declared NONDISPLAY input fields.
- Deliberately excluded cursor position and transient operator-error text from change-password state identity, so moving into a protected area does not create a false new state.
- Added generic `FIELD_COUNT_EQ` known-state criterion.
- Added `pub400_password_expiry_probe.rex`: login, confirm password-expiry state, send one Enter, capture/learn Change Password, then stop without requesting or sending a new password.
- Persist the observed password-expiry `ENTER` transition as knowledge rather than action authority.
- Added regressions for both new states, cursor-independent matching, field-topology rejection and JSON transition round-trip.

# v0.4.1

- Handle enhanced-Telnet `DEVNAME` collision retries instead of re-sending the same unavailable device name until the server disconnects.
- Preserve the requested device identity separately from the current negotiated candidate.
- Deterministic bounded collision naming: `AIBOT0001` -> `AIBOT0002` -> `AIBOT0003`; unsuffixed names gain a four-digit suffix.
- Expose the actual negotiated device name and collision count to trusted runtime diagnostics and live tools.
- Add RFC collision regression coverage, including the rule that an initial specific `DEVNAME` request is not itself a collision.

# v0.4

- Added generic `TerminalCredentialLease`, provider and broker capability objects; lease retirement removes retained credential references without claiming secure Rexx-memory zeroization.
- Added `KnownState5250Factory` to learn a conservative `IBM_I_SIGNON` matcher from a confirmed structured 5250 snapshot.
- Added generic known-state criteria for case-insensitive row text and field topology at a screen position.
- Added `TN5250CredentialLogin~stage()` which requires an exact known-state match before acquiring credentials.
- Added trusted transactional username/password pair staging; a password can only be placed in a host-declared NONDISPLAY input field and partial staging rolls back.
- Kept credential staging and AID submission separate; the safe stage result exposes only credential reference, field ids and a redacted snapshot.
- Added one-shot and test credential providers.  The automation facade still has no credential-lease API.
- Extended the credential-free PUB400 probe to optionally persist the observed sign-on screen as `IBM_I_SIGNON` without input/AID.
- Added `pub400_login_once.rex`, an explicit local-operator acceptance tool which requires a persisted known state, reads password only from `/dev/tty` with echo disabled, sends one login ENTER, displays the first host response, and sends no post-login command.
- Added regressions for learned-state volatility/topology matching, known-state JSON round-trip, secret-free traces, wrong-state refusal before credential acquisition, trusted-wire-only secret presence and transactional overflow rollback.

# v0.3.1

- Replaced the Debian/Ubuntu-specific default CA bundle with fail-closed portable Unix trust-store discovery.
- Added openSUSE/SLES bundle locations (`/etc/ssl/ca-bundle.pem` and `/var/lib/ca-certificates/ca-bundle.pem`) plus RHEL/Fedora, Alpine, Arch/p11-kit, BSD and FreeBSD candidates.
- Added explicit CA file/path support and application-scoped `OOREXX_TERMINAL_CA_FILE` / `OOREXX_TERMINAL_CA_PATH` overrides before standard OpenSSL environment variables.
- Added `capath` support for hashed CA directories where an aggregate bundle is unavailable.
- Added trust-source diagnostics to the credential-free live probe.
- TLS verification remains mandatory in verified mode; there is still no plaintext or unverified fallback.

# v0.3

- Split TN5250 into a trusted `TN5250RuntimeSession` and an AI/operator-safe `TN5250AutomationSession`.
- Removed raw outbound wire bytes from safe action results; actions now expose only `transportOutputPending`.
- Added explicit System Request control-signal path and RFC1205 `x'0400'` generation.
- Added RFC1205 Cancel Invite acknowledgement.
- Added READ MODIFIED IMMEDIATE ALTERNATE (`x'83'`) with AID `x'00'` and conservative Query capability advertisement.
- Kept READ IMMEDIATE (`x'72'`) fail-closed until byte-exact format-table/regeneration semantics exist.
- Added trusted private presentation capture and session-local opaque SAVE/RESTORE images; nondisplay data does not appear in the wire save token.
- Added optional verified `SocatTlsTerminalTransport` with no plaintext fallback.
- Added bounded transport readiness/receive operations.
- Added `tools/pub400_probe.rex`, a credential-free TLS/TN5250 first-screen probe with no field or AID action path.
- Added regressions for immediate alternate reads, control flow, SAVE/RESTORE secret preservation, raw-wire boundary sealing, transport waits and verified TLS.

# v0.2

- Added native 5250 workstation datastream parser/state machine.
- Added WTD base orders, FFW/FCW parsing and nondisplay field handling.
- Corrected WTD CC0 to IBM MSB-first bit numbering; added all-mode regression.
- Preserved MDT across null-only WTD operations unless the control byte explicitly resets it.
- Added RFC1205 Query Reply with conservative capability advertisement.
- Added READ INPUT / READ MDT input encoding and delayed AID/READ state.
- Added high-level TN5250 composition.
- Sealed mutable model/raw driver/raw Telnet getters from the AI-facing surface.
- Added vertical byte-stream -> WatchAlong -> AI -> byte-stream regression.

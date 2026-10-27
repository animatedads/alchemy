## v0.22-candidate13

- Add `S3270Reference.cls`, a read-only parser for retained `s3270 ReadBuffer(Ascii)` evidence and zero-origin cursor coordinates.
- Add semantic differential comparison between Terminal Machine detached 3270 snapshots and the independent s3270 reference: dimensions, cursor, visible rows, field addresses/lengths, protection, numeric, MDT and NONDISPLAY state.
- Mask NONDISPLAY data in exported reference snapshots; raw secret bytes are not retained as comparison values.
- Fail closed on unsupported multi-byte/DBCS ReadBuffer cell tokens instead of flattening them into false single-cell equality.
- Add `test_s3270_reference.rex` with positive semantic equivalence and deliberate cursor-mismatch detection.
- Add `tools/s3270_differential_compare.rex` as an observation-only normalizer for retained s3270 captures. It does not connect to or mutate a host.
- Advance the next live gate to same-environment Terminal Machine vs s3270 differential qualification on ED209Z.

## candidate12

- correct host screen/round-trip meter facts to use the gate's configured protocol source, so TN3270 ownership does not emit historical TN5250 labels;

- add reference-backed `MVS.ISPF.PRIMARY_OPTION_MENU` recognition from the exact TK5 Figure 17 screen;
- require corroborating title, option prompt and END instruction rather than a single loose substring;
- retain a sanitized ISPF primary-menu reference fixture with variable status fields omitted;
- record current ConnectSelector v0.1-dev6 as an optional adapter boundary, not a native TN3270 dependency.

## v0.22-candidate11

- Promote live ED209Z/ED209ZZ reference evidence into conservative native 3270 semantic states: Hercules/TK5 welcome panel, TSO logon prompt, TSO current-password prompt and TSO READY.
- Add generic `ANY_ROW_EQUALS_CI` known-state criterion so authentication-sensitive states can require an exact trimmed screen row rather than a substring.
- Require exact-row `READY` evidence; negative regressions prove `READY TO PROCESS`, unrelated messages and echoed command text do not authenticate a session.
- Generalise the observed `ENTER CURRENT PASSWORD FOR HERC03-` evidence only to the stable visible prompt prefix; no userid or credential becomes terminal authority.
- Keep ISPF deliberately unregistered because the reviewed live evidence says the primary menu was reached but does not retain an exact screen exemplar suitable for a semantic fingerprint.
- Add `qualification/MVS3270_LIVE_EVIDENCE.md` documenting the evidence/authority boundary.
- Add the candidate10 TN3270 ownership/control regressions to the normal `run_tests.sh` list.
- Re-check the 2026-10-09 ConnectSelector/RPC alignment material: no transport framework is made a dependency of the native 3270 engine.

## v0.22-candidate10

- Connect native TN3270/TN3270E live sessions to the existing `TerminalSessionOwner` exact-object ownership contract.
- Add a snapshot-only TN3270 observer facade and a private TN3270 mutation port behind `TerminalControlGate`.
- Preserve the legacy direct TN3270 cursor/input/AID API only for unclaimed sessions; once an owner claims the session, direct mutation fails closed.
- Reuse the existing one-writer/many-readers control model for 3270 field write, cursor movement, field navigation, AID and reset operations.
- Keep TN3270E SYSREQ unavailable unless the negotiated wire profile genuinely supports it.
- Generalize `TerminalControlGate` meter-source labelling so 3270 work is recorded as `TN3270` instead of historical `TN5250`.
- Re-check current Library Socket Provider v0.1-dev14 and XTP v0.1-dev18. The public provider contract now contains descriptor/readiness delegation for providers that implement it, but the current `RxSockTcpBinding` still returns an ordinary `.Socket` without provider-level connection readiness/descriptor support. Terminal Machine therefore retains its qualified `TcpTerminalTransport` and does not unwrap `SocketEndpoint~raw` or silently switch TN3270 to a blocking provider path.

## v0.22-candidate1
- Adds transport-independent IBM 3270 Model 2 presentation/data-stream engine.
- Adds traditional TN3270 Telnet profile and EOR record bridge.
- Adds protocol-driven live session waits; no fixed sleep in success path.
- TN3270E and extended attributes intentionally remain follow-on work.

## v0.22-candidate4
- Makes READ BUFFER and READ MODIFIED executable terminal responses rather than accepted-but-inert command markers.
- TN3270 now emits EOR-framed replies for host read commands while keeping Telnet negotiation output on the same outbound boundary.
- READ BUFFER reconstructs Start Field orders and field attributes from the native presentation-space model.
- READ MODIFIED now uses circular 3270 field extents, including fields which wrap across the end of the Model-2 buffer, and supports unformatted buffers.
- WCC reset-MDT clears modified flags without destroying field/data state.
- Adds focused regressions for read responses, wire framing, MDT reset and wrapped fields under ooRexx 5.3.0 r13196.

## v0.22-candidate2
- Corrects ooRexx USE ARG defaults found by execution under ooRexx 5.3.0 r13196.
- Adds IBM 3270 PF1-PF24 and PA1-PA3 AID constants.
- Adds generation-driven Enter/PF helpers and text predicate waiting; no fixed sleeps.
- PF AID values are cross-checked against IBM CICS 3270 AID documentation.

## v0.22-candidate5
- Implements native 3270 extended attributes instead of rejecting SFE/SA/MF orders.
- SFE now creates fields with a retained basic field attribute plus detached extended field attributes (highlighting, foreground, character set, background, and unknown attribute types).
- SA now tracks character-attribute runs across ordinary data and RA, including reset-all semantics; EUA clears character attributes with erased data.
- MF now modifies an existing field at the selected field-attribute address and fails closed when the current buffer address is not a field attribute.
- READ BUFFER reconstructs SFE and SA orders so presentation styling is not flattened when the terminal is read back.
- Adds 1-based row/column addressing and native input-field editing to the 3270 presentation space, plus matching TN3270LiveSession helpers. Operator input retains the native MDT/READ MODIFIED path rather than inventing a text protocol.
- Adds focused r13196 regressions for SFE/SA/MF, READ BUFFER attribute reconstruction, protected/range failures, coordinate input, cursor-relative input and modified-field wire output.

## v0.22-candidate6
- Adds RFC 2355 basic TN3270E negotiation while retaining traditional TN3270 fallback.
- Adds TN3270E Telnet option 40, DEVICE-TYPE negotiation, server-assigned device-name retention, and null FUNCTIONS negotiation. Candidate6 deliberately claims no optional TN3270E functions until their semantics exist.
- Adds the mandatory five-byte TN3270E message header and applies it to inbound 3270-DATA, host read responses, and operator AID records only after DEVICE-TYPE and FUNCTIONS negotiation complete.
- Accepts NVT-DATA as a distinct basic-TN3270E record and retains it separately instead of feeding it into the 3270 datastream parser. Unsupported TN3270E data types fail closed.
- Fixes an r13196 non-short-circuit NIL dereference in unformatted presentation-space text rendering exposed by the new TN3270E regression.
- Adds `tools/hercules_tn3270_probe.rex`, a complete observation-only real-environment probe for a Hercules TN3270/TN3270E listener.
- Adds focused r13196 regression coverage for TN3270E option/device/functions negotiation, header framing/stripping, host reads, operator AIDs, function refusal and NVT separation.

## v0.22-candidate8
- Adds native Write Structured Field command handling for the 3270 path instead of rejecting `F3` as an unsupported command.
- Implements Read Partition Query and Query List for the implicit Model-2 presentation space, returning inbound Query Reply structured fields with the required structured-field AID (`X'88'`).
- Query replies advertise only semantics actually implemented by Terminal Machine in this candidate: Summary, Usable Area (24x80 / 1920 cells), Color, and Extended Highlighting. Unsupported Query-List requests return the protocol Null Query Reply rather than inventing capability.
- Adds strict structured-field length, partition, query-list request-type and unsupported-SFID validation.
- Adds Set Reply Mode parsing but deliberately accepts only Field mode; Extended Field and Character reply modes fail closed until their inbound read semantics are implemented.
- Adds executable Read Modified All (`X'6E'`) and Erase All Unprotected (`X'6F'`). EAU preserves protected fields, clears unprotected field data and character attributes, resets MDT, unlocks the keyboard and positions the cursor at the first unprotected field.
- TN3270 and basic TN3270E now EOR-frame Write Structured Field query replies at the same wire boundary as other terminal-generated records.
- Adds focused r13196 regressions for WSF Query, Query List/Null replies, capability honesty, Set Reply Mode refusal, EAU, RMA, and TN3270 wire framing.

## v0.22-candidate9 — native 3270 detached semantic snapshots

- Adds `TN3270Snapshot`, projecting the mutable 3270 presentation space into the generic detached `TerminalSnapshot` contract while preserving field geometry, basic/extended field attributes, MDT/protection/numeric state, cursor, keyboard state and terminal capabilities.
- NONDISPLAY 3270 field values are masked as `<SECRET>` in detached snapshots and excluded from visible text/content fingerprints.
- `TN3270LiveSession~snapshot` now exposes the detached semantic view without changing its existing constructor or TN3270/TN3270E wire API.
- Adds generic `ANY_ROW_CONTAINS_CI` known-state criterion for layout-independent terminal recognition.
- Adds the first conservative MVS 3270 known state: `MVS.TSO.LOGON_PROMPT`, based on the already observed `Logon ===>` terminal evidence. No `READY`, VTAM or ISPF state is guessed without captured evidence.
- Adds an observation-only `hercules_tn3270_semantic_probe.rex` environment probe that prints protocol/device facts, detached snapshot fingerprints, known-state result and the visible 24x80 presentation space without sending an AID.

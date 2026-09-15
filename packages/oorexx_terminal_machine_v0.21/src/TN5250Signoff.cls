/*
 * Trusted IBM i main-menu signoff staging.
 *
 * This helper recognizes only a previously confirmed IBM_I_MAIN_MENU state,
 * locates the host-declared command/selection field, and stages the literal
 * menu choice "90".  It deliberately does not press Enter.  The caller must
 * authorize and send the AID as a separate operation.
 */

::class TN5250SignoffBuild public
::constant RELEASE "0.1"
::constant API_VERSION "terminal.tn5250.signoff/0.1"

::class TN5250SignoffStageResult public
::attribute stateId get
::attribute commandFieldId get
::attribute snapshot get

::method init
  expose stateId commandFieldId snapshot
  use arg stateIdArg, commandFieldIdArg, snapshotArg
  stateId = stateIdArg~string
  commandFieldId = commandFieldIdArg~string
  snapshot = snapshotArg~copyDetached

::class TN5250Signoff public
::method stage90 class
  use arg runtime, catalog, expectedStateIdArg = "IBM_I_MAIN_MENU"
  if runtime == .nil then return .TerminalResult~failure("SIGNOFF_RUNTIME_REQUIRED", "runtime is required")
  if catalog == .nil then return .TerminalResult~failure("SIGNOFF_CATALOG_REQUIRED", "known-state catalog is required")

  snap = runtime~snapshot
  matched = catalog~match(snap)
  if matched~status \== .TerminalMatchStatus~MATCH then do
    return .TerminalResult~failure("SIGNOFF_STATE_NOT_CONFIRMED", "expected=" || expectedStateIdArg || " match=" || matched~status)
  end
  if matched~matchedStateId \== expectedStateIdArg then do
    return .TerminalResult~failure("SIGNOFF_WRONG_STATE", "expected=" || expectedStateIdArg || " got=" || matched~matchedStateId)
  end

  mapped = .KnownState5250Factory~findMainMenuCommandField(snap)
  if \mapped~ok then return mapped
  field = mapped~value

  staged = runtime~automationPort~setField(snap~generation, field~fieldId, "90", "LOCAL_SIGNOFF")
  if \staged~ok then return staged

  return .TerminalResult~success(.TN5250SignoffStageResult~new(expectedStateIdArg, field~fieldId, runtime~snapshot))

::requires "TN5250CredentialLogin.cls"


/*
 * Broker-owned orderly IBM i signoff for persistent service shutdown, v0.17.
 *
 * This helper is intentionally invoked only after remote protocol capabilities
 * have been quiesced and the socket service has drained.  It does not bypass
 * TerminalSessionBroker control: it attaches one local service observer,
 * requires the exact confirmed IBM_I_MAIN_MENU known state, acquires normal
 * externally admitted control, stages literal option 90, sends one ENTER, and
 * then sends no further input.  A host screen change or remote close is treated
 * as the terminal-side response to signoff; the broker is then closed to
 * release the one persistent live-session ownership claim.
 */
::class TN5250BrokerSignoffResult public
::attribute outcome get
::attribute stateId get
::attribute commandFieldId get
::attribute beforeAidGeneration get
::attribute finalGeneration get
::attribute finalBrokerState get

::method init
  expose outcome stateId commandFieldId beforeAidGeneration finalGeneration finalBrokerState
  use strict arg outcomeArg, stateIdArg, commandFieldIdArg, beforeArg, finalArg, brokerStateArg
  outcome = outcomeArg~string
  stateId = stateIdArg~string
  commandFieldId = commandFieldIdArg~string
  beforeAidGeneration = beforeArg
  finalGeneration = finalArg
  finalBrokerState = brokerStateArg~string


::class TN5250BrokerSignoff public
::method perform class
  use strict arg broker, catalog, reservation, principalArg = "TERMINAL_SERVICE_SIGNOFF", maxPumpsArg = 10, pumpTimeoutSecondsArg = 1
  if broker == .nil then return .TerminalResult~failure("BROKER_SIGNOFF_BROKER_REQUIRED")
  if catalog == .nil then return .TerminalResult~failure("BROKER_SIGNOFF_CATALOG_REQUIRED")
  if reservation == .nil then return .TerminalResult~failure("BROKER_SIGNOFF_ADMISSION_REQUIRED")
  if \datatype(maxPumpsArg, "W") then return .TerminalResult~failure("BROKER_SIGNOFF_PUMP_LIMIT_INVALID")
  if maxPumpsArg < 1 | maxPumpsArg > 120 then return .TerminalResult~failure("BROKER_SIGNOFF_PUMP_LIMIT_INVALID")
  if \datatype(pumpTimeoutSecondsArg, "N") then return .TerminalResult~failure("BROKER_SIGNOFF_PUMP_TIMEOUT_INVALID")
  if pumpTimeoutSecondsArg < 0 | pumpTimeoutSecondsArg > 30 then return .TerminalResult~failure("BROKER_SIGNOFF_PUMP_TIMEOUT_INVALID")
  principal = principalArg~string~strip
  if principal == "" then return .TerminalResult~failure("BROKER_SIGNOFF_PRINCIPAL_REQUIRED")

  required = .array~of("ATTACHEDCLIENTCOUNT", "CONTROLACTIVE", "ATTACHCLIENT", "PUMPONCE", "STATUS", "CLOSE")
  do methodName over required
    if \broker~hasMethod(methodName) then return .TerminalResult~failure("BROKER_SIGNOFF_BROKER_INVALID", "missing " || methodName)
  end
  if broker~attachedClientCount \= 0 then return .TerminalResult~failure("BROKER_SIGNOFF_SERVICE_NOT_QUIESCED", "attached clients=" || broker~attachedClientCount)
  if broker~controlActive then return .TerminalResult~failure("BROKER_SIGNOFF_SERVICE_NOT_QUIESCED", "controller still active")

  attached = broker~attachClient(principal)
  if \attached~ok then return attached
  client = attached~value
  if client == .nil then return .TerminalResult~failure("BROKER_SIGNOFF_CLIENT_INVALID")

  snapResult = client~snapshot
  if \snapResult~ok then do
    ignore = client~detach("SIGNOFF_SNAPSHOT_FAILED")
    return snapResult
  end
  snap = snapResult~value
  matched = catalog~match(snap)
  if matched~status \== .TerminalMatchStatus~MATCH then do
    ignore = client~detach("SIGNOFF_STATE_NOT_CONFIRMED")
    return .TerminalResult~failure("SIGNOFF_STATE_NOT_CONFIRMED", matched~status)
  end
  if matched~matchedStateId \== "IBM_I_MAIN_MENU" then do
    ignore = client~detach("SIGNOFF_WRONG_STATE")
    return .TerminalResult~failure("SIGNOFF_WRONG_STATE", matched~matchedStateId)
  end

  mapped = .KnownState5250Factory~findMainMenuCommandField(snap)
  if \mapped~ok then do
    ignore = client~detach("SIGNOFF_FIELD_MAPPING_FAILED")
    return mapped
  end
  commandField = mapped~value

  capabilities = .array~of(.TerminalControlCapability~FIELD_WRITE, .TerminalControlCapability~AID)
  acquired = client~requestControl(reservation, capabilities)
  if \acquired~ok then do
    ignore = client~detach("SIGNOFF_CONTROL_FAILED")
    return acquired
  end
  controller = acquired~value

  staged = controller~setField(snap~generation, commandField~fieldId, "90")
  if \staged~ok then do
    if controller~active then ignore = controller~release("SIGNOFF_STAGE_FAILED")
    ignore = client~detach("SIGNOFF_STAGE_FAILED")
    return staged
  end

  stagedSnapshotResult = controller~snapshot
  if \stagedSnapshotResult~ok then do
    if controller~active then ignore = controller~release("SIGNOFF_SNAPSHOT_FAILED")
    ignore = client~detach("SIGNOFF_SNAPSHOT_FAILED")
    return stagedSnapshotResult
  end
  stagedSnapshot = stagedSnapshotResult~value
  beforeAidGeneration = stagedSnapshot~generation

  pressed = controller~press(beforeAidGeneration, "ENTER")
  if \pressed~ok then do
    if controller~active then ignore = controller~release("SIGNOFF_ENTER_FAILED")
    ignore = client~detach("SIGNOFF_ENTER_FAILED")
    /* A failed ENTER is not a successful host signoff.  Keep the retained
     * broker/session open and quiesced for diagnosis rather than using a raw
     * transport close as a substitute for IBM i signoff. */
    return pressed
  end
  if controller~active then ignore = controller~release("ORDERLY_SIGNOFF_AID_SENT")

  /* No further input is sent after ENTER.  Only observe bounded host progress. */
  do pumpIndex = 1 to maxPumpsArg
    pumped = broker~pumpOnce(pumpTimeoutSecondsArg, 16384)
    if \pumped~ok then do
      ignore = client~detach("SIGNOFF_PUMP_FAILED")
      /* Observation failure cannot prove the host signed off.  Preserve the
       * retained session for trusted diagnosis; never turn uncertainty into a
       * generic close. */
      return pumped
    end
    status = broker~status
    finalState = status~state
    pumpValue = pumped~value
    finalSnapshot = .nil
    if pumpValue \== .nil then do
      if pumpValue~hasMethod("SNAPSHOT") then finalSnapshot = pumpValue~snapshot
    end
    if finalState == "REMOTE_CLOSED" | finalState == "CLOSED" then do
      finalGeneration = beforeAidGeneration
      if finalSnapshot \== .nil then finalGeneration = finalSnapshot~generation
      ignore = client~detach("ORDERLY_SIGNOFF_REMOTE_CLOSED")
      closed = broker~close
      if \closed~ok then return closed
      return .TerminalResult~success(.TN5250BrokerSignoffResult~new("REMOTE_CLOSED", "IBM_I_MAIN_MENU", commandField~fieldId, beforeAidGeneration, finalGeneration, "CLOSED"))
    end
    if finalSnapshot \== .nil then do
      if finalSnapshot~generation > beforeAidGeneration then do
        finalGeneration = finalSnapshot~generation
        ignore = client~detach("ORDERLY_SIGNOFF_SCREEN_UNCONFIRMED")
        /* A changed screen is evidence, not proof of signoff.  It may be a
         * host error or an as-yet-unlearned semantic state.  Follow the known-
         * state discipline: send no more input and keep the broker open until
         * the new state is learned/confirmed. */
        return .TerminalResult~failure("SIGNOFF_SCREEN_CHANGED_UNCONFIRMED", "from=" || beforeAidGeneration || ";to=" || finalGeneration)
      end
    end
  end

  ignore = client~detach("ORDERLY_SIGNOFF_TIMEOUT")
  /* Timeout likewise does not prove host signoff.  Leave the retained session
   * open and quiesced for a trusted operator rather than silently disconnecting
   * it through the generic broker close path. */
  return .TerminalResult~failure("SIGNOFF_TIMEOUT", "generation=" || beforeAidGeneration)

::requires "TerminalControl.cls"

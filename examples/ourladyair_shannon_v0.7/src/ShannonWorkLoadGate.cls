/* Shannon workload admission for terminal actions.
 *
 * Work Load Units are RESOURCE accounting, not money and not Legal Effect.
 * This gate can refuse an expensive/bursty terminal operation before any host
 * mutation.  It cannot make a sale lawful, alter booking facts, or override
 * HardWorld.
 */

::class ShannonWorkLoadGate public
::attribute authority get
::attribute identity get

::method init
  expose authority identity
  use strict arg authorityArg, identityArg = 'SHANNON_AGENT'
  /* The loaded API identity is evidence.  Required behaviour is exercised by
     WLUAuthority reserve/admit/settle rather than release-number gating. */
  if authorityArg == .nil | \authorityArg~isA(.WLUAuthority) then -
    raise syntax 88.900 array('ShannonWorkLoadGate requires a WLUAuthority')
  authority = authorityArg
  identity = identityArg~string~strip~upper
  if identity = '' then raise syntax 88.900 array('Shannon workload identity must not be empty')

::method workLoadApiVersion
  return .WLUDBuild~API_VERSION

::method reserveTerminalAction
  expose authority identity
  use strict arg sessionId, fieldWrites = 0, aids = 1, screenUpdates = 1, roundTrips = 1, bytesRx = 0, bytesTx = 0, knownStateEvaluations = 0, controlLeaseMillis = 0, ttlSeconds = 30, correlationId = ''
  facts = self~terminalFacts(fieldWrites, aids, screenUpdates, roundTrips, bytesRx, bytesTx, knownStateEvaluations, controlLeaseMillis)
  scope = 'TERMINAL:' || sessionId~string~strip
  if scope = 'TERMINAL:' then return .WLUResult~failure('WLU_INVALID_SCOPE', 'terminal session id must not be empty')
  return authority~reserveFacts(identity, scope, facts, ttlSeconds, correlationId)

::method admit
  expose authority
  use strict arg reservation
  return authority~admit(reservation)

::method settleTerminalAction
  expose authority
  use strict arg reservation, fieldWrites = 0, aids = 1, screenUpdates = 1, roundTrips = 1, bytesRx = 0, bytesTx = 0, knownStateEvaluations = 0, controlLeaseMillis = 0
  facts = self~terminalFacts(fieldWrites, aids, screenUpdates, roundTrips, bytesRx, bytesTx, knownStateEvaluations, controlLeaseMillis)
  return authority~settleFacts(reservation, facts)

::method release
  expose authority
  use strict arg reservation
  return authority~release(reservation)

::method terminalFacts private
  use strict arg fieldWrites, aids, screenUpdates, roundTrips, bytesRx, bytesTx, knownStateEvaluations, controlLeaseMillis
  facts = .array~new
  if fieldWrites > 0 then facts~append(.WLUFact~new('FIELD_WRITE', fieldWrites, 'SHANNON_TERMINAL'))
  if aids > 0 then facts~append(.WLUFact~new('AID', aids, 'SHANNON_TERMINAL'))
  if screenUpdates > 0 then facts~append(.WLUFact~new('SCREEN_UPDATE', screenUpdates, 'SHANNON_TERMINAL'))
  if roundTrips > 0 then facts~append(.WLUFact~new('HOST_ROUND_TRIP', roundTrips, 'SHANNON_TERMINAL'))
  if bytesRx > 0 then facts~append(.WLUFact~new('BYTES_RX', bytesRx, 'SHANNON_TERMINAL'))
  if bytesTx > 0 then facts~append(.WLUFact~new('BYTES_TX', bytesTx, 'SHANNON_TERMINAL'))
  if knownStateEvaluations > 0 then facts~append(.WLUFact~new('KNOWN_STATE_EVALUATION', knownStateEvaluations, 'SHANNON_TERMINAL'))
  if controlLeaseMillis > 0 then facts~append(.WLUFact~new('CONTROL_LEASE_TIME', controlLeaseMillis, 'SHANNON_TERMINAL'))
  return facts

/* Executes only after authenticated WLU admission.  The terminal object owns
 * protocol semantics; this class owns only resource admission and settlement.
 */
::class ShannonTerminalWorkController public
::attribute gate get

::method init
  expose gate
  use strict arg gateArg
  if gateArg == .nil | \gateArg~isA(.ShannonWorkLoadGate) then -
    raise syntax 88.900 array('ShannonTerminalWorkController requires ShannonWorkLoadGate')
  gate = gateArg

::method executeAID
  expose gate
  use strict arg terminal, sessionId, aid, fieldWrites = 0, screenUpdates = 1, roundTrips = 1, ttlSeconds = 30
  reserved = gate~reserveTerminalAction(sessionId, fieldWrites, 1, screenUpdates, roundTrips, 0, 0, 0, 0, ttlSeconds, 'shannon-terminal-' || .DateTime~new~microseconds)
  if \reserved~ok then return reserved
  reservation = reserved~value

  admitted = gate~admit(reservation)
  if \admitted~ok then do
    ignored = gate~release(reservation)
    return admitted
  end

  terminalResult = terminal~executeAID(aid)
  settled = gate~settleTerminalAction(reservation, fieldWrites, 1, screenUpdates, roundTrips)
  if \settled~ok then return settled

  payload = .directory~new
  payload['terminalResult'] = terminalResult
  payload['reservationId'] = reservation~reservationId
  payload['rateCardId'] = reservation~rateCardId
  payload['rateCardVersion'] = reservation~rateCardVersion
  payload['reservedMicroWlu'] = reservation~reservedMicroWlu
  payload['workAuthority'] = 'RESOURCE_ADMISSION_ONLY'
  payload['workLoadApiVersion'] = gate~workLoadApiVersion
  return .WLUResult~success(payload)

::requires 'WorkLoadUnits.cls'

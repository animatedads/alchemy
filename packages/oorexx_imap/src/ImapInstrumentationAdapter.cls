/* ooRexx IMAP -> Instrumentation Mesh adapter v0.1-dev13
 *
 * This is an optional observation adapter.  IMAP remains authoritative for
 * protocol/session semantics; Instrumentation Mesh owns telemetry vocabulary,
 * snapshot/history/publication semantics.  No command or mailbox mutation
 * authority is granted by this adapter.
 */

::class ImapInstrumentationBuild public
::constant API "imap.instrumentation/0.1"
::constant RELEASE "0.1-dev13"

::class ImapInstrumentationMetric public
::constant SESSIONS_ACCEPTED_TOTAL "imap.sessions.accepted.total"
::constant SESSIONS_CLOSED_TOTAL "imap.sessions.closed.total"
::constant SESSIONS_ACTIVE "imap.sessions.active"
::constant SESSIONS_SELECTED "imap.sessions.selected"
::constant SESSIONS_AUTHENTICATED "imap.sessions.authenticated"
::constant TLS_SESSIONS_ACCEPTED_TOTAL "imap.sessions.tls.accepted.total"
::constant PLAINTEXT_SESSIONS_ACCEPTED_TOTAL "imap.sessions.plaintext.accepted.total"
::constant AUTH_ATTEMPTS_TOTAL "imap.authentication.attempts.total"
::constant AUTH_SUCCEEDED_TOTAL "imap.authentication.succeeded.total"
::constant AUTH_FAILED_TOTAL "imap.authentication.failed.total"
::constant LITERAL_BYTES_IN_TOTAL "imap.literal.bytes.in.total"
::constant TRANSPORT_FAILURES_TOTAL "imap.transport.failures.total"
::constant PROTOCOL_BAD_TOTAL "imap.protocol.bad.total"
::constant PROTOCOL_NO_TOTAL "imap.protocol.no.total"
::constant PROTOCOL_OK_TOTAL "imap.protocol.ok.total"
::constant IDLE_STARTED_TOTAL "imap.idle.started.total"
::constant IDLE_STOPPED_TOTAL "imap.idle.stopped.total"
::constant IDLE_ACTIVE "imap.idle.active"
::constant IDLE_UPDATES_TOTAL "imap.idle.updates.total"
::constant IDLE_EVENTS_TOTAL "imap.idle.events.total"

/* One instance is intended to be shared by all sessions of one resident IMAP
 * service instance.  Guarded ooRexx methods serialize updates to its counters. */
::class ImapInstrumentationSource public
::method init
  expose emitter activeSessions selectedSessions authenticatedSessions idleSessions
  use strict arg identityArg
  if identityArg == .nil then raise syntax 88.900 array("IMAP_INSTRUMENTATION_IDENTITY_REQUIRED")
  emitter = .InstrumentationEmitter~new(identityArg)
  activeSessions = 0
  selectedSessions = 0
  authenticatedSessions = 0
  idleSessions = 0
  emitter~setHealth(.InstrumentationHealth~HEALTHY)
  self~publishSessionGauges

::method publishSessionGauges
  expose emitter activeSessions selectedSessions authenticatedSessions idleSessions
  emitter~gaugeSet(.ImapInstrumentationMetric~SESSIONS_ACTIVE, activeSessions)
  emitter~gaugeSet(.ImapInstrumentationMetric~SESSIONS_SELECTED, selectedSessions)
  emitter~gaugeSet(.ImapInstrumentationMetric~SESSIONS_AUTHENTICATED, authenticatedSessions)
  emitter~gaugeSet(.ImapInstrumentationMetric~IDLE_ACTIVE, idleSessions)
  return self

::method sessionOpened
  expose emitter activeSessions
  use strict arg tlsActive = .false
  activeSessions += 1
  emitter~counterAdd(.ImapInstrumentationMetric~SESSIONS_ACCEPTED_TOTAL, 1)
  if tlsActive == .true then emitter~counterAdd(.ImapInstrumentationMetric~TLS_SESSIONS_ACCEPTED_TOTAL, 1)
  else emitter~counterAdd(.ImapInstrumentationMetric~PLAINTEXT_SESSIONS_ACCEPTED_TOTAL, 1)
  self~publishSessionGauges
  return self

::method sessionClosed
  expose emitter activeSessions selectedSessions authenticatedSessions
  use strict arg finalState = ""
  state = finalState~string~upper
  if activeSessions > 0 then activeSessions -= 1
  if state = "SELECTED" then do
    if selectedSessions > 0 then selectedSessions -= 1
    if authenticatedSessions > 0 then authenticatedSessions -= 1
  end
  else if state = "AUTHENTICATED" then do
    if authenticatedSessions > 0 then authenticatedSessions -= 1
  end
  emitter~counterAdd(.ImapInstrumentationMetric~SESSIONS_CLOSED_TOTAL, 1)
  self~publishSessionGauges
  return self

::method stateTransition
  expose selectedSessions authenticatedSessions
  use strict arg oldStateArg, newStateArg
  oldState = oldStateArg~string~upper
  newState = newStateArg~string~upper
  if oldState = newState then return self

  if oldState = "NOT_AUTHENTICATED" then do
    if newState = "AUTHENTICATED" | newState = "SELECTED" then authenticatedSessions += 1
  end
  if oldState = "AUTHENTICATED" then do
    if newState = "LOGOUT" | newState = "NOT_AUTHENTICATED" then do
      if authenticatedSessions > 0 then authenticatedSessions -= 1
    end
  end
  if oldState = "SELECTED" then do
    if newState <> "SELECTED" then do
      if selectedSessions > 0 then selectedSessions -= 1
    end
    if newState = "LOGOUT" | newState = "NOT_AUTHENTICATED" then do
      if authenticatedSessions > 0 then authenticatedSessions -= 1
    end
  end
  if newState = "SELECTED" then do
    if oldState <> "SELECTED" then selectedSessions += 1
  end
  self~publishSessionGauges
  return self

::method commandAccepted
  expose emitter
  use strict arg commandArg
  command = self~metricCommand(commandArg)
  emitter~requestAccepted
  emitter~counterAdd("imap.command." || command || ".accepted.total", 1)
  if command = "login" then emitter~counterAdd(.ImapInstrumentationMetric~AUTH_ATTEMPTS_TOTAL, 1)
  return self

::method commandCompleted
  expose emitter
  use strict arg commandArg, statusArg
  command = self~metricCommand(commandArg)
  status = statusArg~string~strip~upper
  emitter~requestCompleted
  emitter~counterAdd("imap.command." || command || ".completed.total", 1)
  if status = "OK" then do
    emitter~counterAdd(.ImapInstrumentationMetric~PROTOCOL_OK_TOTAL, 1)
    emitter~counterAdd("imap.command." || command || ".ok.total", 1)
    if command = "login" then emitter~counterAdd(.ImapInstrumentationMetric~AUTH_SUCCEEDED_TOTAL, 1)
  end
  else if status = "NO" then do
    emitter~counterAdd(.ImapInstrumentationMetric~PROTOCOL_NO_TOTAL, 1)
    emitter~counterAdd("imap.command." || command || ".no.total", 1)
    if command = "login" then emitter~counterAdd(.ImapInstrumentationMetric~AUTH_FAILED_TOTAL, 1)
  end
  else do
    emitter~counterAdd(.ImapInstrumentationMetric~PROTOCOL_BAD_TOTAL, 1)
    emitter~counterAdd("imap.command." || command || ".bad.total", 1)
    if command = "login" then emitter~counterAdd(.ImapInstrumentationMetric~AUTH_FAILED_TOTAL, 1)
  end
  return self

::method commandFailed
  expose emitter
  use strict arg commandArg, codeArg = ""
  command = self~metricCommand(commandArg)
  emitter~requestFailed
  emitter~counterAdd("imap.command." || command || ".failed.total", 1)
  return self

::method idleStarted
  expose emitter idleSessions
  idleSessions += 1
  emitter~counterAdd(.ImapInstrumentationMetric~IDLE_STARTED_TOTAL, 1)
  self~publishSessionGauges
  return self

::method idleStopped
  expose emitter idleSessions
  use strict arg reasonArg = ""
  if idleSessions > 0 then idleSessions -= 1
  emitter~counterAdd(.ImapInstrumentationMetric~IDLE_STOPPED_TOTAL, 1)
  self~publishSessionGauges
  return self

::method idleUpdate
  expose emitter
  use strict arg eventCountArg = 0
  emitter~counterAdd(.ImapInstrumentationMetric~IDLE_UPDATES_TOTAL, 1)
  if datatype(eventCountArg, "W") then do
    if eventCountArg > 0 then emitter~counterAdd(.ImapInstrumentationMetric~IDLE_EVENTS_TOTAL, eventCountArg)
  end
  return self

::method bytesIn
  expose emitter
  use strict arg bytes
  if datatype(bytes, "W") then do
    if bytes >= 0 then emitter~bytesIn(bytes)
  end
  return self

::method bytesOut
  expose emitter
  use strict arg bytes
  if datatype(bytes, "W") then do
    if bytes >= 0 then emitter~bytesOut(bytes)
  end
  return self

::method literalBytesIn
  expose emitter
  use strict arg bytes
  if datatype(bytes, "W") then do
    if bytes >= 0 then emitter~counterAdd(.ImapInstrumentationMetric~LITERAL_BYTES_IN_TOTAL, bytes, "bytes")
  end
  return self

::method transportFailure
  expose emitter
  use strict arg codeArg = ""
  emitter~counterAdd(.ImapInstrumentationMetric~TRANSPORT_FAILURES_TOTAL, 1)
  emitter~setHealth(.InstrumentationHealth~DEGRADED)
  return self

::method healthy
  expose emitter
  emitter~setHealth(.InstrumentationHealth~HEALTHY)
  return self

::method snapshot
  expose emitter
  use strict arg observedAt = ""
  return emitter~snapshot(observedAt)

::method metricCommand
  use strict arg commandArg
  source = commandArg~string~strip~lower
  if source = "" then return "unknown"
  out = ""
  do i = 1 to source~length
    c = source~substr(i, 1)
    if datatype(c, "A") then out ||= c
    else if datatype(c, "N") then out ||= c
    else out ||= "_"
  end
  do while out~pos("__") > 0; out = out~changeStr("__", "_"); end
  out = out~strip("B", "_")
  if out = "" then out = "unknown"
  if out~length > 48 then out = out~left(48)
  return out

::requires "InstrumentationMesh.cls"

/* CASTV2 live probe over an ALREADY ACQUIRED, authenticated TLS stream.
   No socket creation, certificate decisions or network fallback live here. */
::class CastLiveProbe public
::method init
  expose connection sessionState
  use strict arg connection
  if connection=.nil then raise syntax 88.900 array('TLS CastConnection is required')
  sessionState='NEW'
::attribute sessionState get
::method start
  expose connection sessionState
  if sessionState<>'NEW' then raise syntax 88.900 array('probe already started')
  cc=.CastConnectionController~new(connection)
  if cc~connect<>.true then do
    sessionState='FAILED'
    return .false
  end
  sessionState='CONNECTED'
  return .true
::method ping
  expose connection sessionState
  if sessionState<>'CONNECTED' then raise syntax 88.900 array('connect first')
  hc=.CastHeartbeatController~new(connection)
  return hc~ping
::method receiverStatus
  expose connection sessionState
  if sessionState<>'CONNECTED' then raise syntax 88.900 array('connect first')
  rc=.CastReceiverController~new(connection)
  return rc~getStatus
::method observe
  expose connection sessionState
  if sessionState<>'CONNECTED' then raise syntax 88.900 array('connect first')
  /* Transmission does not imply the remote receiver replied. */
  return connection~receive
::method close
  expose connection sessionState
  if sessionState='CLOSED' then return .true
  connection~close
  sessionState='CLOSED'
  return .true
::requires 'Chromecast.cls'

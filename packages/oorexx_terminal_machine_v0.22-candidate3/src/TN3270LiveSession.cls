/* Blocking-on-protocol TN3270 session.  No sleeps occur on the success path:
 * select() bounds failure; EOR records and presentation-space generations
 * drive progress. */
::class TN3270LiveSession public
::attribute transport get
::attribute wire get
::method init
  expose transport wire
  use arg transportArg, wireArg=.nil
  transport=transportArg
  if wireArg==.nil then wire=.TN3270Wire~new; else wire=wireArg
::method open
  expose transport
  return transport~open
::method pumpUntilGeneration
  expose transport wire
  use arg afterGeneration, timeoutSeconds=10
  deadline=time('E')+timeoutSeconds
  do while wire~model~generation<=afterGeneration
    remaining=timeoutSeconds-(time('E')-(deadline-timeoutSeconds))
    if remaining<=0 then return .TerminalResult~failure("TN3270_STATE_TIMEOUT",timeoutSeconds)
    ready=transport~waitReadable(remaining)
    if \ready~ok then return ready
    if \ready~value then return .TerminalResult~failure("TN3270_STATE_TIMEOUT",timeoutSeconds)
    got=transport~receiveBytes(16384)
    if \got~ok then return got
    if got~value~length==0 then return .TerminalResult~failure("TN3270_REMOTE_CLOSED")
    wire~feed(got~value)
    outbound=wire~drainOutbound
    if outbound~length>0 then do; sent=transport~sendBytes(outbound); if \sent~ok then return sent; end
  end
  return .TerminalResult~success(wire~model~generation)
::method sendAidAndAwait
  expose transport wire
  use arg aid="7D"x, timeoutSeconds=10
  before=wire~model~generation
  payload=wire~stream~buildReadModified(aid)
  sent=transport~sendBytes(wire~frameInput(payload)); if \sent~ok then return sent
  return self~pumpUntilGeneration(before,timeoutSeconds)
::method enterAndAwait
  use arg timeoutSeconds=10
  return self~sendAidAndAwait(.Aid3270~ENTER, timeoutSeconds)
::method pfAndAwait
  use arg number, timeoutSeconds=10
  if number<1 | number>24 then return .TerminalResult~failure("3270_BAD_PF",number)
  name="PF"||number
  aid=.Aid3270~send(name)
  return self~sendAidAndAwait(aid,timeoutSeconds)
::method awaitText
  expose wire
  use arg needle, timeoutSeconds=10
  start=wire~model~generation
  do forever
    rendered=wire~model~text(wire~stream~codepage)
    if rendered~pos(needle)>0 then return .TerminalResult~success(wire~model~generation)
    r=self~pumpUntilGeneration(wire~model~generation,timeoutSeconds)
    if \r~ok then return r
  end
::method close
  expose transport
  return transport~close
::requires "TN3270Wire.cls"
::requires "TerminalTransport.cls"
